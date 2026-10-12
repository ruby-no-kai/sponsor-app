# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Broadcasts", type: :request do
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first) }

  before do
    get claim_user_session_path(FactoryBot.create(:session_token, email: sponsorship.contact.email).handle)
  end

  it "lists sent broadcasts with the login link filled in" do
    broadcast = FactoryBot.create(:broadcast, conference:, status: :sent, body: 'Visit @LOGIN@')
    FactoryBot.create(:broadcast_delivery, broadcast:, sponsorship:)

    get user_conference_sponsorship_broadcasts_path(conference)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(<a href="#{user_conference_sponsorship_url(conference)}">))
    expect(response.body).not_to include('@LOGIN@')
  end
end
