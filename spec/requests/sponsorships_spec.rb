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

  context "when amendment is closed" do
    let(:conference) { FactoryBot.create(:conference, :full, application_opens_at: 2.days.ago, amendment_closes_at: 1.day.ago) }
    let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:) }

    before do
      get claim_user_session_path(FactoryBot.create(:session_token, email: sponsorship.contact.email).handle)
    end

    it "responds with 404 on edit" do
      get edit_user_conference_sponsorship_path(conference)
      expect(response).to have_http_status(:not_found)
    end

    it "responds with 404 on update and keeps the name" do
      patch user_conference_sponsorship_path(conference), params: {sponsorship: {name: 'Renamed'}}
      expect(response).to have_http_status(:not_found)
      expect(sponsorship.reload.name).not_to eq('Renamed')
    end
  end

  context "when amendment is closed with staff" do
    let(:conference) { FactoryBot.create(:conference, :full, application_opens_at: 2.days.ago, amendment_closes_at: 1.day.ago) }
    let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:) }

    before do
      get claim_user_session_path(FactoryBot.create(:session_token, :with_staff).handle)
      get claim_user_session_path(FactoryBot.create(:session_token, email: sponsorship.contact.email).handle)
    end

    it "renders edit" do
      get edit_user_conference_sponsorship_path(conference)
      expect(response).to have_http_status(:ok)
    end

    it "renames on update" do
      patch user_conference_sponsorship_path(conference), params: {sponsorship: {name: 'Renamed'}}
      expect(response).to have_http_status(:found)
      expect(sponsorship.reload.name).to eq('Renamed')
    end
  end
end
