# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Admin Plans", type: :request do
  let(:conference) { FactoryBot.create(:conference) }
  let(:staff) { FactoryBot.create(:staff) }
  let(:session_token) { FactoryBot.create(:session_token, staff:) }

  before do
    get claim_user_session_path(session_token.handle)
  end

  describe "GET index" do
    it "lists plans of the conference" do
      plan = FactoryBot.create(:plan, conference:)
      get conference_plans_path(conference)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(plan.name)
    end
  end

  describe "GET new" do
    it "renders the form" do
      get new_conference_plan_path(conference)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST create" do
    it "creates a plan for the conference" do
      expect do
        post conference_plans_path(conference), params: {plan: {name: 'Gold', rank: 1, summary: 's', capacity: 3, number_of_guests: 1, price_text: 'p', words_limit: 10}}
      end.to change(conference.plans, :count).by(1)

      expect(response).to redirect_to(conference_plans_path(conference))
    end
  end

  describe "existing plan" do
    let!(:plan) { FactoryBot.create(:plan, conference:) }

    it "renders the edit form" do
      get edit_conference_plan_path(conference, plan)
      expect(response).to have_http_status(:ok)
    end

    it "updates the plan" do
      patch conference_plan_path(conference, plan), params: {plan: {name: 'Renamed'}}

      expect(response).to redirect_to(conference_plans_path(conference))
      expect(plan.reload.name).to eq('Renamed')
    end

    it "does not find a plan of another conference" do
      other_plan = FactoryBot.create(:plan)

      get edit_conference_plan_path(conference, other_plan)

      expect(response).to have_http_status(:not_found)
    end
  end
end
