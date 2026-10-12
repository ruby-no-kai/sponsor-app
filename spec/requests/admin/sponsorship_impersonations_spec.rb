# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Admin Sponsorship Impersonations", type: :request do
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first) }
  let(:staff) { FactoryBot.create(:staff) }
  let(:session_token) { FactoryBot.create(:session_token, staff:) }

  before do
    get claim_user_session_path(session_token.handle)
  end

  describe "POST create" do
    context "when impersonation is enabled" do
      before do
        allow(Rails.configuration.x.dev).to receive(:sponsor_impersonation).and_return(true)
      end

      it "issues a session token for the primary contact and redirects to claim it" do
        expect do
          post conference_sponsorship_impersonation_path(conference, sponsorship)
        end.to change(SessionToken, :count).by(1)

        token = SessionToken.order(:id).last
        expect(token.email).to eq(sponsorship.contact.email)
        expect(response).to redirect_to(claim_user_session_path(token))
      end
    end

    context "when impersonation is disabled" do
      it "responds not found" do
        post conference_sponsorship_impersonation_path(conference, sponsorship)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
