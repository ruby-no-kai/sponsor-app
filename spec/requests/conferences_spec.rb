# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Conferences", type: :request do
  describe "GET index" do
    it "redirects to the only open conference" do
      conference = FactoryBot.create(:conference, application_opens_at: 1.day.ago, hidden: false)

      get user_conferences_path
      expect(response).to redirect_to(user_conference_sponsorship_path(conference))
    end

    it "lists several open conferences" do
      FactoryBot.create_list(:conference, 2, application_opens_at: 1.day.ago, hidden: false)

      get user_conferences_path
      expect(response).to have_http_status(:ok)
    end

    it "redirects a sponsor to their latest sponsorship when none is open" do
      conference = FactoryBot.create(:conference, :full)
      sponsorship = FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first)
      get claim_user_session_path(FactoryBot.create(:session_token, email: sponsorship.contact.email).handle)

      get user_conferences_path
      expect(response).to redirect_to(user_conference_sponsorship_path(conference))
    end

    it "renders when nothing is open and there is no session" do
      get user_conferences_path
      expect(response).to have_http_status(:ok)
    end
  end
end
