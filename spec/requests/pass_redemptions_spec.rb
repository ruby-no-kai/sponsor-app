# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Pass redemptions", type: :request do
  let(:conference) { FactoryBot.create(:conference, :full, tito_slug: 'rubykaigi/2099', ticket_distribution_starts_at: 1.day.ago) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first) }

  before do
    get claim_user_session_path(FactoryBot.create(:session_token, email: sponsorship.contact.email).handle)
  end

  it "lists the sponsorship's registrations" do
    allow(PassRedemption).to receive(:list_for_sponsorship).and_return(PassRedemption::Collection.new(registrations: [], valid_discount_codes: []))

    get user_conference_sponsorship_pass_redemptions_path(conference)
    expect(response).to have_http_status(:ok)
    expect(PassRedemption).to have_received(:list_for_sponsorship).with(sponsorship)
  end

  it "shows the tickets made with the sponsorship's codes" do
    FactoryBot.create(:tito_discount_code, sponsorship:, code: 'SPONSOR1')
    FactoryBot.create(:tito_cached_release, conference:, tito_release_id: '11', tito_release_slug: 'exhibitor')
    TitoSource.create!(conference:, sponsorship:, tito_source_id: '1')
    tickets = [
      {id: 2, reference: 'ABCD-1', discount_code_used: 'SPONSOR1', release_id: 11, email: 'a@example.invalid', state: 'complete', void: false, assigned: true},
      {id: 3, reference: 'ABCD-2', discount_code_used: 'OTHER', release_id: 11, email: 'b@example.invalid', state: 'complete', void: false, assigned: true},
    ]
    registration = {
      id: 1, slug: 'reg-abcd', reference: 'ABCD', discount_code: 'SPONSOR1', source: 'ss_1', email: 'a@example.invalid', state: 'complete',
      free: true, paid: false, cancelled: false, refunded: false, partially_refunded: false, tickets:,
    }
    allow(TitoApi).to receive(:new).and_return(instance_double(TitoApi, list_registrations: {registrations: [registration], meta: {total_pages: 1}}))

    get user_conference_sponsorship_pass_redemptions_path(conference)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('ABCD-1', '<span class="badge badge-dark">Booth pass</span>', new_user_conference_sponsorship_retraction_path(conference, 1))
    expect(response.body).not_to include('ABCD-2')
    expect(response.body).not_to include('btn-outline-danger d-none')
  end

  describe "the note on voiding" do
    before do
      conference.update!(contact_email_address: 'sponsors+<b>@example.invalid')
      allow(PassRedemption).to receive(:list_for_sponsorship).and_return(PassRedemption::Collection.new(registrations: [], valid_discount_codes: []))
    end

    it "links the contact address, escaped, while voiding is enabled" do
      get user_conference_sponsorship_pass_redemptions_path(conference)

      expect(response.body).to include('<a href="mailto:sponsors+&lt;b&gt;@example.invalid">sponsors+&lt;b&gt;@example.invalid</a>')
      expect(response.body).not_to include('<b>')
    end

    it "links the contact address, escaped, once voiding is disabled" do
      conference.update!(pass_retraction_disables_at: 1.day.ago)

      get user_conference_sponsorship_pass_redemptions_path(conference)

      expect(response.body).to include('please contact <a href="mailto:sponsors+&lt;b&gt;@example.invalid">')
      expect(response.body).not_to include('<b>')
    end
  end

  it "is not found before ticket distribution starts" do
    conference.update!(ticket_distribution_starts_at: 1.day.from_now)

    get user_conference_sponsorship_pass_redemptions_path(conference)
    expect(response).to have_http_status(:not_found)
  end
end
