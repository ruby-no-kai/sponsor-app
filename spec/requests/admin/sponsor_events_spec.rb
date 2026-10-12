# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Admin Sponsor Events", type: :request do
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first) }
  let!(:sponsor_event) { FactoryBot.create(:sponsor_event, sponsorship:, title: 'Meetup') }
  let(:staff) { FactoryBot.create(:staff) }
  let(:session_token) { FactoryBot.create(:session_token, staff:) }

  before do
    get claim_user_session_path(session_token.handle)
  end

  describe "GET index" do
    it "lists events of the conference" do
      get conference_sponsor_events_path(conference)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Meetup')
    end
  end

  describe "GET show" do
    it "shows the event" do
      get conference_sponsor_event_path(conference, sponsor_event)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(sponsorship.name)
    end
  end

  describe "GET editing_histories" do
    it "lists the edits of the event" do
      get conference_sponsor_event_editing_histories_path(conference, sponsor_event)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET download_asset" do
    it "responds not found without an asset" do
      get download_asset_conference_sponsor_event_path(conference, sponsor_event)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH update" do
    it "updates the event as the current staff" do
      allow(ProcessSponsorEventEditJob).to receive(:perform_later)

      patch conference_sponsor_event_path(conference, sponsor_event), params: {sponsor_event: {status: 'accepted', co_host_sponsorship_ids: ''}}

      expect(response).to redirect_to(conference_sponsor_event_path(conference, sponsor_event))
      expect(sponsor_event.reload).to be_accepted
      history = sponsor_event.editing_histories.reorder(:id).last
      expect(history.staff).to eq(staff)
      expect(ProcessSponsorEventEditJob).to have_received(:perform_later).with(history)
    end
  end
end
