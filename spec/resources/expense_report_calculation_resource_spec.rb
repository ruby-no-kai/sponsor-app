# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExpenseReportCalculationResource do
  let(:conference) { FactoryBot.create(:conference) }
  let(:plan) { FactoryBot.create(:plan, conference:, price: 3_000_000, price_booth: 500_000) }

  it 'builds the configured tax rates and the plan prices as decimal strings' do
    sponsorship = FactoryBot.build(:sponsorship, conference:, plan:)

    expect(described_class.new(sponsorship).as_protobuf).to eq(Rk::SponsorApp::ExpenseReportCalculation.new(
      tax_rates: %w(0.1 0.08 0.0),
      decimal: 0,
      plan_price: '3000000.0',
      plan_price_booth: '500000.0',
      booth_assigned: false,
      total_fee: '3000000.0',
    ))
  end

  it 'adds the booth price to the fee once a booth is assigned' do
    sponsorship = FactoryBot.build(:sponsorship, conference:, plan:, booth_assigned: true)

    expect(described_class.new(sponsorship).as_protobuf).to have_attributes(booth_assigned: true, total_fee: '3500000.0')
  end

  it 'leaves the plan prices unset and the fee zero without a plan' do
    calculation = described_class.new(FactoryBot.build(:sponsorship, conference:, plan: nil)).as_protobuf

    expect(calculation).to have_attributes(has_plan_price?: false, has_plan_price_booth?: false, total_fee: '0')
  end
end
