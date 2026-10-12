# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "SponsorEvents", type: :request do
  let(:conference) { FactoryBot.create(:conference, :full, application_opens_at: 1.day.ago, event_submission_starts_at: 1.day.ago) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first, accepted_at: Time.current) }
  let(:sponsor_event) { FactoryBot.create(:sponsor_event, :pending, sponsorship:) }

  before do
    allow(ProcessSponsorEventEditJob).to receive(:perform_later)
    get claim_user_session_path(FactoryBot.create(:session_token, email: sponsorship.contact.email).handle)
  end

  it "renders show with links to the conference's event" do
    get user_conference_sponsorship_event_path(conference, sponsor_event)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(edit_user_conference_sponsorship_event_path(conference, sponsor_event))
  end

  it "redirects to the sponsorship after withdrawing" do
    delete user_conference_sponsorship_event_path(conference, sponsor_event)
    expect(response).to redirect_to(user_conference_sponsorship_path(conference))
  end

  it "redirects to the sponsorship when event submission is not open" do
    conference.update!(event_submission_starts_at: nil)
    get new_user_conference_sponsorship_event_path(conference)
    expect(response).to redirect_to(user_conference_sponsorship_path(conference))
  end
end
