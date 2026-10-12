# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Pass retractions", type: :request do
  let(:conference) { FactoryBot.create(:conference, :full, tito_slug: 'rubykaigi/2099', ticket_distribution_starts_at: 1.day.ago) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first) }
  let(:registration) do
    {
      'reference' => 'ABC123',
      'slug' => 'abc123',
      'free' => true,
      'paid' => false,
      'refunded' => false,
      'partially_refunded' => false,
      'cancelled' => false,
      'tickets' => [{'release_id' => 'rel_1', 'discount_code_used' => 'SPONSOR'}],
    }
  end
  let(:tito_api) { instance_double(TitoApi, get_registration: {registration:}) }

  before do
    allow(TitoApi).to receive(:new).and_return(tito_api)
    get claim_user_session_path(FactoryBot.create(:session_token, email: sponsorship.contact.email).handle)
  end

  it "renders the retraction form for a registration" do
    get new_user_conference_sponsorship_retraction_path(conference, 'reg_1')
    expect(response).to have_http_status(:ok)
    expect(tito_api).to have_received(:get_registration).with('rubykaigi/2099', 'reg_1', 'expand' => 'tickets')
  end

  context "with a completed retraction" do
    before do
      FactoryBot.create(:tito_discount_code, sponsorship:, code: 'SPONSOR2025')
      FactoryBot.create(:tito_ticket_retraction, :with_tito_registration, sponsorship:, tito_registration_id: 'reg_1', completed: true)
    end

    it "redirects the form to it" do
      get new_user_conference_sponsorship_retraction_path(conference, 'reg_1')
      expect(response).to redirect_to(user_conference_sponsorship_retraction_path(conference, 'reg_1'))
    end

    it "shows it" do
      get user_conference_sponsorship_retraction_path(conference, 'reg_1')
      expect(response).to have_http_status(:ok)
    end
  end

  it "is not found once retraction is disabled" do
    conference.update!(pass_retraction_disables_at: 1.day.ago)

    post user_conference_sponsorship_retraction_path(conference, 'reg_1'), params: {tito_ticket_retraction: {reason: 'no longer attending'}}
    expect(response).to have_http_status(:not_found)
  end

  it "is not found without a tito event" do
    conference.update!(tito_slug: nil)

    get user_conference_sponsorship_retraction_path(conference, 'reg_1')
    expect(response).to have_http_status(:not_found)
  end
end
