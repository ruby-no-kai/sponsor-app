# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Sponsor events", type: :request do
  let(:conference) { FactoryBot.create(:conference, :full, event_submission_starts_at: 1.day.ago) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first, accepted_at: Time.current) }
  let(:event_params) { {title: 'Meetup', starts_at: 1.week.from_now.iso8601, url: 'https://meetup.invalid'} }

  before do
    allow(ProcessSponsorEventEditJob).to receive(:perform_later)
    get claim_user_session_path(FactoryBot.create(:session_token, email: sponsorship.contact.email).handle)
  end

  describe "GET new" do
    it "renders the form" do
      get new_user_conference_sponsorship_event_path(conference)
      expect(response).to have_http_status(:ok)
    end

    it "redirects when event submission is not open" do
      conference.update!(event_submission_starts_at: 1.day.from_now)
      get new_user_conference_sponsorship_event_path(conference)
      expect(URI(response.location).path).to eq(user_conference_sponsorship_path(conference))
    end

    it "redirects when the sponsorship is not accepted" do
      sponsorship.update!(accepted_at: nil)
      get new_user_conference_sponsorship_event_path(conference)
      expect(URI(response.location).path).to eq(user_conference_sponsorship_path(conference))
    end
  end

  describe "POST create" do
    it "creates the event with its uploaded asset file" do
      asset_file = FactoryBot.create(:sponsor_event_asset_file, sponsorship:)

      post user_conference_sponsorship_events_path(conference), params: {sponsor_event: event_params.merge(policy_agreement: '1', asset_file_id: asset_file.id)}

      event = sponsorship.sponsor_events.last
      expect(URI(response.location).path).to eq(user_conference_sponsorship_event_path(conference, event))
      expect(event.policy_acknowledged_at).to be_present
      expect(event.asset_file).to eq(asset_file)
      expect(ProcessSponsorEventEditJob).to have_received(:perform_later).with(event.last_editing_history)
    end

    it "re-renders the form when invalid" do
      post user_conference_sponsorship_events_path(conference), params: {sponsor_event: event_params.merge(title: '')}
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "existing event" do
    let!(:event) { FactoryBot.create(:sponsor_event, sponsorship:) }

    it "shows the event" do
      get user_conference_sponsorship_event_path(conference, event)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(edit_user_conference_sponsorship_event_path(conference, event))
    end

    it "updates the event" do
      patch user_conference_sponsorship_event_path(conference, event), params: {sponsor_event: {title: 'Renamed'}}
      expect(URI(response.location).path).to eq(user_conference_sponsorship_event_path(conference, event))
      expect(event.reload.title).to eq('Renamed')
    end

    it "withdraws the event" do
      delete user_conference_sponsorship_event_path(conference, event)
      expect(URI(response.location).path).to eq(user_conference_sponsorship_path(conference))
      expect(event.reload).to be_withdrawn
    end

    it "refuses to edit a withdrawn event" do
      event.update!(status: :withdrawn)
      get edit_user_conference_sponsorship_event_path(conference, event)
      expect(URI(response.location).path).to eq(user_conference_sponsorship_event_path(conference, event))
    end
  end
end
