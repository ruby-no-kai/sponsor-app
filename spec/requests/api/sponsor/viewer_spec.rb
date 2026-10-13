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
end
