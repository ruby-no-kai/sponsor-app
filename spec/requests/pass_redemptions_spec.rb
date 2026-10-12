# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Pass redemptions", type: :request do
  let(:conference) { FactoryBot.create(:conference, :full, tito_slug: 'rubykaigi/2099', ticket_distribution_starts_at: 1.day.ago) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first) }

  before do
    get claim_user_session_path(FactoryBot.create(:session_token, email: sponsorship.contact.email).handle)
  end

  it "lists the sponsorship's registrations" do
    allow(PassRedemption).to receive(:list_for_sponsorship).and_return(PassRedemption::Collection.new(registrations: []))

    get user_conference_sponsorship_pass_redemptions_path(conference)
    expect(response).to have_http_status(:ok)
    expect(PassRedemption).to have_received(:list_for_sponsorship).with(sponsorship)
  end

  it "is not found before ticket distribution starts" do
    conference.update!(ticket_distribution_starts_at: 1.day.from_now)

    get user_conference_sponsorship_pass_redemptions_path(conference)
    expect(response).to have_http_status(:not_found)
  end
end
