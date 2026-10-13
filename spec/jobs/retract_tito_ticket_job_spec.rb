# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RetractTitoTicketJob, type: :job do
  let(:conference) { FactoryBot.create(:conference, tito_slug: 'rubykaigi/2026') }
  let(:plan) { FactoryBot.create(:plan, conference:) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:) }
  let(:registration_data) do
    {
      'reference' => 'ABC123',
      'slug' => 'john-doe-abc123',
      'free' => true,
      'paid' => false,
      'refunded' => false,
      'partially_refunded' => false,
      'cancelled' => false,
      'tickets' => [{'release_id' => 'rel_1', 'discount_code_used' => 'SPONSOR2026'}],
    }
  end
  let(:retraction) do
    TitoTicketRetraction.create!(
      sponsorship:,
      conference:,
      tito_registration_id: 'reg_1',
      tito_registration: registration_data,
      reason: 'Sponsor requested cancellation',
      completed: false,
    )
  end
  let(:api) { instance_double(TitoApi) }

  before do
    FactoryBot.create(:tito_discount_code, sponsorship:, code: 'SPONSOR2026')
    FactoryBot.create(:tito_cached_release, conference:, tito_release_id: 'rel_1', tito_release_slug: 'sponsor')
    allow(Rails.application.config.x).to receive(:public_url_host).and_return('test.host')
    allow(TitoApi).to receive(:new).and_return(api)
    allow(api).to receive_messages(get_registration: {registration: registration_data}, cancel_registration: {'cancelled' => true})
    allow(api).to receive(:create_registration_note)
    allow(SlackWebhookJob).to receive(:perform_later)
  end

  it 'cancels the registration and reports it' do
    described_class.perform_now(retraction)

    expect(api).to have_received(:create_registration_note).with(
      'rubykaigi/2026',
      'reg_1',
      content: a_string_including("TitoTicketRetraction id=#{retraction.id}"),
    )
    expect(api).to have_received(:cancel_registration).with('rubykaigi/2026', 'reg_1')
    expect(retraction.reload.completed).to be true
    expect(SlackWebhookJob).to have_received(:perform_later).with(
      text: a_string_including('ABC123', '(sponsor)'),
      hook_name: :feed,
    )
  end

  it 'completes a retraction whose registration is already cancelled, keeping the registration as it now stands' do
    allow(api).to receive(:get_registration).and_return({registration: registration_data.merge('cancelled' => true)})

    described_class.perform_now(retraction)

    expect(api).not_to have_received(:cancel_registration)
    expect(retraction.reload).to have_attributes(completed: true, tito_registration: include('cancelled' => true))
  end

  it 'skips a completed retraction' do
    retraction.update!(completed: true)

    described_class.perform_now(retraction)

    expect(TitoApi).not_to have_received(:new)
  end
end
