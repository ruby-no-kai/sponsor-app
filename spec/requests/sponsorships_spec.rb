# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Sponsorships", type: :request do
  let(:conference) { FactoryBot.create(:conference, :full, application_opens_at: 1.day.ago) }
  let(:plan) { conference.plans.first }

  before do
    allow(SponsorshipWelcomeJob).to receive(:perform_later)
    allow(ProcessSponsorshipEditJob).to receive(:perform_later)
  end

  describe "POST create" do
    let(:asset_file_id) do
      allow_any_instance_of(SponsorshipAssetFile).to receive(:make_session).and_return({}) # rubocop:disable RSpec/AnyInstance
      post user_conference_sponsorship_asset_files_path(conference), params: {content_type: 'image/png'}
      session[:asset_file_ids].last
    end

    let(:sponsorship_params) do
      {
        plan_id: plan.id,
        name: 'Contoso',
        url: 'https://contoso.invalid',
        profile: 'we are contoso',
        asset_file_id:,
        contact_attributes: {email: 'sponsor@contoso.invalid', address: 'addr', organization: 'Contoso', name: 'User'},
      }
    end

    it "creates a sponsorship when the policy is agreed" do
      post user_conference_sponsorship_path(conference), params: {sponsorship: sponsorship_params.merge(policy_agreement: '1')}
      expect(response).to have_http_status(:found)
      expect(conference.sponsorships.count).to eq(1)
    end

    it "ignores asset_file_id_to_copy" do
      post user_conference_sponsorship_path(conference), params: {sponsorship: sponsorship_params.merge(policy_agreement: '1', asset_file_id_to_copy: '1')}
      expect(response).to have_http_status(:found)
      expect(conference.sponsorships.count).to eq(1)
    end

    it "rejects an application with the policy checkbox unchecked" do
      post user_conference_sponsorship_path(conference), params: {sponsorship: sponsorship_params.merge(policy_agreement: '0')}
      expect(response).to have_http_status(:ok)
      expect(conference.sponsorships.count).to eq(0)
    end

    it "rejects an application without policy_agreement" do
      post user_conference_sponsorship_path(conference), params: {sponsorship: sponsorship_params}
      expect(response).to have_http_status(:ok)
      expect(conference.sponsorships.count).to eq(0)
    end
  end

  describe "PATCH update" do
    let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:) }
    let(:session_token) { FactoryBot.create(:session_token, email: sponsorship.contact.email) }

    before do
      get claim_user_session_path(session_token.handle)
    end

    it "does not require policy agreement on amendment" do
      patch user_conference_sponsorship_path(conference), params: {sponsorship: {name: 'Renamed'}}
      expect(response).to have_http_status(:found)
      expect(sponsorship.reload.name).to eq('Renamed')
    end
  end
end
