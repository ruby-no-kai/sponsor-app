# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EnsureSponsorshipTitoDiscountCodeJob, type: :job do
  let(:conference) { FactoryBot.create(:conference, tito_slug: 'rubykaigi/2026') }
  let(:plan) { FactoryBot.create(:plan, conference:, number_of_guests: 3) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:, accepted_at: Time.current) }
  let(:api) { instance_double(TitoApi) }

  before do
    allow(Rails.application.config.x.tito).to receive(:token).and_return('token')
    allow(TitoApi).to receive(:new).and_return(api)
    allow(api).to receive_messages(
      create_source: {source: {id: 11}},
      get_release: {release: {id: 22}},
      create_discount_code: {discount_code: {id: 33}},
      update_discount_code: {discount_code: {id: 33}},
    )
  end

  it 'creates a discount code for a sponsorship without one' do
    described_class.perform_now(sponsorship, 'attendee')

    expect(api).to have_received(:create_discount_code).with(
      'rubykaigi/2026',
      code: "sa_#{sponsorship.id}_#{sponsorship.ticket_key[0, 12]}",
      type: 'PercentOffDiscountCode',
      value: '100.0',
      only_show_attached: true,
      reveal_secret: true,
      block_registrations_if_not_applicable: false,
      quantity: 3,
      release_ids: ['22'],
      source_id: '11',
      description_for_organizer: "sponsorship=#{sponsorship.id}, domain=#{sponsorship.organization.domain}, plan=#{plan.name}",
    )
    expect(api).to have_received(:get_release).with('rubykaigi/2026', 'sponsor')
    expect(sponsorship.tito_discount_codes.sole).to have_attributes(kind: 'attendee', quantity: 3, tito_discount_code_id: '33')
    expect(sponsorship.reload.tito_source.tito_source_id).to eq('11')
  end

  it 'updates an existing discount code whose quantity changed' do
    discount_code = FactoryBot.create(:tito_discount_code, sponsorship:, kind: :attendee, quantity: 1, tito_discount_code_id: 'dc_1')

    described_class.perform_now(sponsorship, 'attendee')

    expect(api).to have_received(:update_discount_code).with('rubykaigi/2026', 'dc_1', hash_including(quantity: 3))
    expect(discount_code.reload.quantity).to eq(3)
  end

  it 'sends nil release_ids when the quantity drops to zero' do
    FactoryBot.create(:tito_discount_code, sponsorship:, kind: :attendee, quantity: 3, tito_discount_code_id: 'dc_1')
    sponsorship.update!(withdrawn_at: Time.current)

    described_class.perform_now(sponsorship, 'attendee')

    expect(api).to have_received(:update_discount_code).with('rubykaigi/2026', 'dc_1', hash_including(quantity: 0, release_ids: nil))
    expect(api).not_to have_received(:get_release)
  end

  it 'leaves an up-to-date discount code alone' do
    FactoryBot.create(:tito_discount_code, sponsorship:, kind: :attendee, quantity: 3)

    described_class.perform_now(sponsorship, 'attendee')

    expect(api).not_to have_received(:update_discount_code)
  end

  it 'gives paid booth staff the conference flat discount' do
    conference.update!(tito_booth_paid_flat_discount_amount: 5000)
    sponsorship.update!(booth_assigned: true)

    described_class.perform_now(sponsorship, 'booth_paid')

    expect(api).to have_received(:create_discount_code).with(
      'rubykaigi/2026',
      code: "se_#{sponsorship.id}_#{sponsorship.ticket_key[0, 12]}",
      type: 'MoneyOffDiscountCode',
      value: '5000.0',
      only_show_attached: true,
      reveal_secret: true,
      block_registrations_if_not_applicable: true,
      quantity: 6,
      release_ids: ['22'],
      source_id: '11',
      description_for_organizer: "sponsorship=#{sponsorship.id}, domain=#{sponsorship.organization.domain}, plan=#{plan.name}",
    )
    expect(api).to have_received(:get_release).with('rubykaigi/2026', 'exhibitor-paid')
  end

  it 'does nothing for a conference without a tito_slug' do
    conference.update!(tito_slug: nil)

    described_class.perform_now(sponsorship, 'attendee')

    expect(TitoApi).not_to have_received(:new)
    expect(sponsorship.tito_discount_codes).to be_empty
  end
end
