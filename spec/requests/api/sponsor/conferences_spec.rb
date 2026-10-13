# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SponsorService conferences', type: :request do
  describe 'ListOpenConferences' do
    let(:rpc) { connect_method('SponsorService', 'ListOpenConferences') }
    let(:request_message) { Rk::SponsorApp::SponsorServiceListOpenConferencesRequest.new }

    let!(:open_conference) { FactoryBot.create(:conference, application_opens_at: 1.day.ago, application_closes_at: 1.day.from_now) }
    let!(:open_without_end) { FactoryBot.create(:conference, application_opens_at: 1.day.ago) }

    before do
      FactoryBot.create(:conference, application_opens_at: 1.day.ago, hidden: true)
      FactoryBot.create(:conference, application_opens_at: 2.days.ago, application_closes_at: 1.day.ago)
      FactoryBot.create(:conference, application_opens_at: 1.day.from_now)
      FactoryBot.create(:conference)
    end

    it 'lists the public conferences taking applications, oldest first' do
      conferences = connect_call(rpc, request_message).conferences

      expect(conferences.map(&:slug)).to eq([open_conference.slug, open_without_end.slug])
      expect(conferences.first).to have_attributes(
        name: open_conference.name,
        contact_email_address: open_conference.contact_email_address,
        application_closes_at: Google::Protobuf::Timestamp.new(seconds: open_conference.application_closes_at.to_i, nanos: open_conference.application_closes_at.nsec),
      )
    end

    it 'answers a GET and a binary call alike' do
      expected = connect_call(rpc, request_message)

      expect(connect_call(rpc, request_message, via: :get)).to eq(expected)
      expect(connect_call(rpc, request_message, codec: :proto)).to eq(expected)
    end

    it 'leaves a sponsor session signed in' do
      sponsorship = FactoryBot.create(:sponsorship, conference: open_conference, plan: nil)
      sign_in_sponsor(sponsorship.contact.email)

      connect_call(rpc, request_message, via: :get)

      expect(session[:sponsorship_ids]).to eq([sponsorship.id])
      viewer = connect_call(connect_method('SponsorService', 'GetViewer'), Rk::SponsorApp::SponsorServiceGetViewerRequest.new).viewer
      expect(viewer.sponsorships.map(&:id)).to eq([sponsorship.id])
    end
  end
end
