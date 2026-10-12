# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Admin Booth Assignments", type: :request do
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:plan) { conference.plans.first.tap { |p| p.update!(booth_size: 1) } }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:, booth_requested: true) }
  let(:staff) { FactoryBot.create(:staff) }
  let(:session_token) { FactoryBot.create(:session_token, staff:) }

  before do
    sponsorship.update!(accepted_at: Time.current)
    get claim_user_session_path(session_token.handle)
  end

  describe "GET show" do
    it "lists sponsorships requesting a booth" do
      get conference_booth_assignment_path(conference)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(sponsorship.name)
    end
  end

  describe "PATCH update" do
    it "assigns booths and records the edit by the current staff" do
      allow(ProcessSponsorshipEditJob).to receive(:perform_later)

      patch conference_booth_assignment_path(conference), params: {booth_assignments: {sponsorship.id.to_s => '1'}}

      expect(response).to redirect_to(conference_booth_assignment_path(conference))
      expect(sponsorship.reload.booth_assigned).to be(true)
      history = sponsorship.editing_histories.reorder(:id).last
      expect(history.staff).to eq(staff)
      expect(ProcessSponsorshipEditJob).to have_received(:perform_later).with(history)
    end
  end
end
