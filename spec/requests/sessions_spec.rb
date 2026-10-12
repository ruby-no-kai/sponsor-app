# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Sessions", type: :request do
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first) }

  describe "GET claim" do
    it "signs in and redirects to the sponsorship" do
      token = FactoryBot.create(:session_token, email: sponsorship.contact.email)

      get claim_user_session_path(token.handle)
      expect(response).to redirect_to(user_conference_sponsorship_path(conference))
      expect(session[:sponsorship_ids]).to eq([sponsorship.id])
      expect(session[:session_token_id]).to eq(token.id)
    end

    it "redirects to the stored back_to" do
      token = FactoryBot.create(:session_token, email: sponsorship.contact.email)

      get claim_user_session_path(token.handle), params: {back_to: '/conferences'}
      expect(response).to redirect_to('/conferences')
    end

    it "redirects to the root without an active sponsorship" do
      sponsorship.update!(withdrawn_at: Time.current)
      token = FactoryBot.create(:session_token, email: sponsorship.contact.email)

      get claim_user_session_path(token.handle)
      expect(response).to redirect_to('/')
    end

    it "signs in staff" do
      staff = FactoryBot.create(:staff)
      token = FactoryBot.create(:session_token, staff:)

      get claim_user_session_path(token.handle)
      expect(session[:staff_id]).to eq(staff.id)
    end

    it "refuses an expired token" do
      token = FactoryBot.create(:session_token, :expired, email: sponsorship.contact.email)

      get claim_user_session_path(token.handle)
      expect(response).to have_http_status(:forbidden)
      expect(session[:sponsorship_ids]).to be_nil
    end
  end
end
