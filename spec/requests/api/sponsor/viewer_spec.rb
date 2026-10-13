# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SponsorService viewer', type: :request do
  let(:rpc) { connect_method('SponsorService', 'GetViewer') }
  let(:request_message) { Rk::SponsorApp::SponsorServiceGetViewerRequest.new }

  describe 'GetViewer' do
    context 'with a sponsor session' do
      let(:email) { 'primary@sponsor.invalid' }
      let!(:older) { create_sponsorship(email) }
      let!(:newer) { create_sponsorship(email) }
      let!(:withdrawn) { create_sponsorship(email, withdrawn_at: Time.zone.now) }

      before do
        create_sponsorship('someone-else@sponsor.invalid')
        sign_in_sponsor(email)
      end

      def create_sponsorship(email, **attributes)
        FactoryBot.create(:sponsorship, **attributes).tap { it.contact.update!(email:) }
      end

      it "returns the contact's sponsorships, newest first, without withdrawn ones" do
        viewer = connect_call(rpc, request_message).viewer

        expect(viewer).to have_attributes(email:, staff: false, locale: 'en')
        expect(viewer.sponsorships.map(&:id)).to eq([newer.id, older.id])
        expect(viewer.sponsorships.first).to have_attributes(name: newer.name)
        expect(viewer.sponsorships.first.conference).to have_attributes(slug: newer.conference.slug, name: newer.conference.name)
        expect(withdrawn).to be_withdrawn
      end

      it 'answers a GET and a binary call alike' do
        expect(connect_call(rpc, request_message, via: :get).viewer.sponsorships.map(&:id)).to eq([newer.id, older.id])
        expect(connect_call(rpc, request_message, codec: :proto).viewer.email).to eq(email)
      end

      it 'switches the locale with hl and remembers it' do
        https! # The locale cookie is Secure.
        get "#{rpc.path}?connect=v1&encoding=json&message=%7B%7D&hl=ja"
        expect(Rk::SponsorApp::SponsorServiceGetViewerResponse.decode_json(response.body).viewer.locale).to eq('ja')

        expect(connect_call(rpc, request_message).viewer.locale).to eq('ja')
      end
    end

    it 'describes a visitor who is not signed in' do
      viewer = connect_call(rpc, request_message).viewer

      expect(viewer).to have_attributes(staff: false, locale: 'en', sponsorships: [])
      expect(viewer.has_email?).to be(false)
    end

    it 'flags a staff session' do
      sign_in_staff(FactoryBot.create(:staff))

      viewer = connect_call(rpc, request_message).viewer

      expect(viewer.staff).to be(true)
      expect(viewer.has_email?).to be(false)
    end
  end

  describe 'SignOut' do
    let(:sign_out) { connect_method('SponsorService', 'SignOut') }
    let(:sign_out_request) { Rk::SponsorApp::SponsorServiceSignOutRequest.new }
    let(:conference) { FactoryBot.create(:conference, :full, application_opens_at: 1.day.ago) }
    let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first) }
    let(:staff) { FactoryBot.create(:staff) }

    before do
      allow(Aws::STS::Client).to receive(:new).and_return(Aws::STS::Client.new(stub_responses: true, region: 'ap-northeast-1'))
      allow(Aws::S3::Client).to receive(:new).and_return(Aws::S3::Client.new(stub_responses: true, region: 'ap-northeast-1'))
    end

    it "drops the contact's session and keeps the staff one" do
      sign_in_staff(staff)
      sign_in_sponsor(sponsorship.contact.email)
      # A logo uploaded for a conference the contact has yet to apply to.
      post user_conference_sponsorship_asset_files_path(FactoryBot.create(:conference, application_opens_at: 1.day.ago)), params: {content_type: 'image/png'}
      expect(session.to_h.keys).to include('email', 'session_token_id', 'sponsorship_ids', 'asset_file_ids', 'staff_id')

      expect(connect_call(sign_out, sign_out_request)).to eq(Rk::SponsorApp::SponsorServiceSignOutResponse.new)

      expect(session.to_h.keys).not_to include('email', 'session_token_id', 'sponsorship_ids', 'sponsorship_id', 'asset_file_ids')
      expect(session[:staff_id]).to eq(staff.id)
      viewer = connect_call(rpc, request_message).viewer
      expect(viewer).to have_attributes(staff: true, has_email?: false, sponsorships: [])
    end

    it 'answers a browser that is not signed in' do
      expect(connect_call(sign_out, sign_out_request)).to eq(Rk::SponsorApp::SponsorServiceSignOutResponse.new)
    end

    it 'refuses a GET, as it has side effects' do
      sign_in_sponsor(sponsorship.contact.email)

      get "#{sign_out.path}?connect=v1&encoding=json&message=%7B%7D"

      expect(response).to have_http_status(:method_not_allowed)
      expect(session[:sponsorship_ids]).to eq([sponsorship.id])
    end
  end
end
