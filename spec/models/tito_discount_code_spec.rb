# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TitoDiscountCode, type: :model do
  let(:conference) { FactoryBot.create(:conference, tito_slug: 'rubykaigi/2025') }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:) }

  describe '#url' do
    it 'links to the discount code on the Tito event' do
      discount_code = FactoryBot.build(:tito_discount_code, sponsorship:, code: 'SPONSOR1')
      expect(discount_code.url).to eq('https://ti.to/rubykaigi/2025/discount/SPONSOR1')
    end

    it 'raises without a sponsorship' do
      discount_code = FactoryBot.build(:tito_discount_code, sponsorship: nil)
      expect { discount_code.url }.to raise_error(Must::Violation)
    end
  end

  describe '#dashboard_orders_url' do
    it 'links to the registrations that used the discount code' do
      discount_code = FactoryBot.build(:tito_discount_code, sponsorship:, code: 'SPONSOR1')
      expect(discount_code.dashboard_orders_url).to eq('https://dashboard.tito.io/rubykaigi/2025/registrations/?search%5Bq%5D=SPONSOR1')
    end
  end
end
