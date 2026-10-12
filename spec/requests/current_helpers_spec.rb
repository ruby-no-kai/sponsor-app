# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "ApplicationController current_* helpers", type: :request do
  let(:conference) { FactoryBot.create(:conference, :full, application_opens_at: 1.day.ago) }
  let(:plan) { conference.plans.first }
  let(:staff) { FactoryBot.create(:staff) }

  def sign_in_staff
    get claim_user_session_path(FactoryBot.create(:session_token, staff:).handle)
  end

  def sign_in_sponsor(sponsorship)
    get claim_user_session_path(FactoryBot.create(:session_token, email: sponsorship.contact.email).handle)
  end

  describe "admin layout" do
    it "renders the login page without a staff session" do
      get new_session_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(organizations_path)
    end

    it "shows the staff login when signed in" do
      sign_in_staff
      get new_session_path
      expect(response.body).to include("@#{staff.login}")
    end
  end

  describe "application layout" do
    it "titles a conference page from the URL without a sponsorship session" do
      get new_user_conference_sponsorship_path(conference)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("| #{conference.name} |")
    end

    it "shows staff mode to staff" do
      sign_in_staff
      get '/'
      expect(response.body).to include('STAFF MODE')
    end
  end

  describe "SponsorshipsController#new" do
    before { conference.update!(application_opens_at: 1.day.from_now) }

    it "renders the closed page without a staff session" do
      get new_user_conference_sponsorship_path(conference)
      expect(response).to have_http_status(:forbidden)
    end

    it "lets staff see the form before application opens" do
      sign_in_staff
      get new_user_conference_sponsorship_path(conference)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("You're seeing this because you're logged in as a staff.")
    end
  end

  describe "SponsorshipsController#edit" do
    it "is not found without a sponsorship session" do
      get edit_user_conference_sponsorship_path(conference)
      expect(response).to have_http_status(:not_found)
    end

    it "is not found for staff without a sponsorship session" do
      sign_in_staff
      get edit_user_conference_sponsorship_path(conference)
      expect(response).to have_http_status(:not_found)
    end

    it "renders for the sponsor" do
      sponsorship = FactoryBot.create(:sponsorship, conference:, plan:)
      sign_in_sponsor(sponsorship)
      get edit_user_conference_sponsorship_path(conference)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "require_sponsorship_session" do
    it "redirects to login without a sponsorship session" do
      get user_conference_sponsorship_broadcasts_path(conference)
      expect(URI(response.location).path).to eq(new_user_session_path)
    end
  end

  describe "populate_sentry_scope" do
    let(:scope) { instance_double(Sentry::Scope, set_context: nil) }

    before do
      allow(Sentry).to receive(:configure_scope).and_yield(scope)
      allow(Sentry).to receive(:set_user)
    end

    it "records the sponsor and conference" do
      sponsorship = FactoryBot.create(:sponsorship, conference:, plan:)
      sign_in_sponsor(sponsorship)
      get user_conference_sponsorship_path(conference)

      expect(scope).to have_received(:set_context).with('sponsor-app.sponsor', {id: sponsorship.id, name: sponsorship.name})
      expect(scope).to have_received(:set_context).with('sponsor-app.conference', {id: conference.id, slug: conference.slug})
      expect(Sentry).to have_received(:set_user).with(id: sponsorship.id.to_s, email: sponsorship.contact.email)
    end

    it "records the staff" do
      sign_in_staff
      get '/'

      expect(scope).to have_received(:set_context).with('sponsor-app.staff', {id: staff.id, login: staff.login})
      expect(Sentry).to have_received(:set_user).with(id: "staff_#{staff.id}", username: staff.login)
    end
  end
end
