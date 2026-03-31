# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExpenseLineItem, type: :model do
  let(:conference) { FactoryBot.create(:conference) }
  let(:plan) { FactoryBot.create(:plan, conference:) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:, customization: true) }
  let(:report) { FactoryBot.create(:expense_report, sponsorship:) }

  describe 'validations' do
    it 'requires title' do
      item = described_class.new(expense_report: report, amount: 100, tax_amount: 0, position: 1)
      expect(item).not_to be_valid
      expect(item.errors[:title]).to be_present
    end

    it 'requires amount >= 0' do
      item = described_class.new(expense_report: report, title: 'Test', amount: -1, tax_amount: 0, position: 1)
      expect(item).not_to be_valid
      expect(item.errors[:amount]).to be_present
    end

    it 'requires tax_amount >= 0' do
      item = described_class.new(expense_report: report, title: 'Test', amount: 100, tax_amount: -1, tax_rate: nil, position: 1)
      expect(item).not_to be_valid
      expect(item.errors[:tax_amount]).to be_present
    end
  end

  describe 'tax calculation' do
    it 'calculates tax_amount from amount and tax_rate on save' do
      item = described_class.create!(expense_report: report, title: 'Meal', amount: 1000, tax_rate: '0.1', tax_amount: 0, position: 1)
      expect(item.tax_amount).to eq(100)
    end

    it 'recalculates on update' do
      item = described_class.create!(expense_report: report, title: 'Meal', amount: 1000, tax_rate: '0.1', tax_amount: 0, position: 1)
      item.update!(amount: 2000)
      expect(item.tax_amount).to eq(200)
    end

    it 'does not override tax_amount when tax_rate is nil' do
      item = described_class.create!(expense_report: report, title: 'Manual', amount: 1000, tax_rate: nil, tax_amount: 150, position: 1)
      expect(item.tax_amount).to eq(150)
    end

    it 'handles 8% rate' do
      item = described_class.create!(expense_report: report, title: 'Food', amount: 1000, tax_rate: '0.08', tax_amount: 0, position: 1)
      expect(item.tax_amount).to eq(80)
    end

    it 'handles 0% rate' do
      item = described_class.create!(expense_report: report, title: 'Exempt', amount: 1000, tax_rate: '0.0', tax_amount: 0, position: 1)
      expect(item.tax_amount).to eq(0)
    end
  end

  describe '#assign_next_position' do
    it 'assigns the next position' do
      described_class.create!(expense_report: report, title: 'First', amount: 100, tax_amount: 10, position: 1)
      item = described_class.new(expense_report: report, title: 'Second', amount: 200, tax_amount: 20)
      item.assign_next_position
      expect(item.position).to eq(2)
    end

    it 'assigns 1 when no items exist' do
      item = described_class.new(expense_report: report, title: 'First', amount: 100, tax_amount: 10)
      item.assign_next_position
      expect(item.position).to eq(1)
    end
  end
end
