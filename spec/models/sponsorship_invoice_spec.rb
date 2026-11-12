# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SponsorshipInvoice do
  subject(:invoice) { described_class.new(sponsorship:) }

  let(:plan) { instance_double(Plan, price: 300_000, price_booth: 50_000) }
  let(:booth_assigned) { true }
  let(:customization) { false }
  let(:expense_report) { nil }
  let(:sponsorship) { instance_double(Sponsorship, plan:, booth_assigned:, customization:, expense_report:) }

  it 'calculates the fees, subtotal, tax, and total' do
    expect(invoice.sponsorship).to eq(sponsorship)
    expect(invoice.plan_amount).to eq(300_000)
    expect(invoice.booth_amount).to eq(50_000)
    expect(invoice.approved_expense_amount).to eq(0)
    expect(invoice.subtotal).to eq(350_000)
    expect(invoice.tax).to eq(35_000)
    expect(invoice.total).to eq(385_000)
    expect(invoice).to be_exportable
  end

  context 'without a booth' do
    let(:booth_assigned) { false }

    it 'does not include the booth fee' do
      expect(invoice.booth_amount).to eq(0)
      expect(invoice.subtotal).to eq(300_000)
    end
  end

  context 'with fractional fees' do
    let(:plan) { instance_double(Plan, price: BigDecimal('100.49'), price_booth: BigDecimal('50.49')) }

    it 'rounds each fee before adding' do
      expect(invoice.plan_amount).to eq(100)
      expect(invoice.booth_amount).to eq(50)
      expect(invoice.subtotal).to eq(150)
    end
  end

  context 'with customized sponsorship' do
    let(:customization) { true }

    it 'does not deduct expenses without a report' do
      expect(invoice.approved_expense_amount).to eq(0)
    end
  end

  context 'with an unapproved report' do
    let(:customization) { true }
    let(:expense_report) { instance_double(ExpenseReport, status: 'submitted', total_amount: 100_000) }

    it 'does not deduct unapproved expenses' do
      expect(invoice.approved_expense_amount).to eq(0)
    end
  end

  context 'with an approved report' do
    let(:customization) { true }
    let(:expense_report) { instance_double(ExpenseReport, status: 'approved', total_amount: expense_amount) }
    let(:expense_amount) { 100_000 }

    it 'deducts the approved expense' do
      expect(invoice.approved_expense_amount).to eq(100_000)
      expect(invoice.subtotal).to eq(250_000)
      expect(invoice.tax).to eq(25_000)
      expect(invoice.total).to eq(275_000)
    end

    context 'with a nil expense amount' do
      let(:expense_amount) { nil }

      it 'uses zero' do
        expect(invoice.approved_expense_amount).to eq(0)
      end
    end

    context 'with fractional amounts' do
      let(:plan) { instance_double(Plan, price: BigDecimal('100.50'), price_booth: BigDecimal('50.50')) }
      let(:expense_amount) { BigDecimal('10.50') }

      it 'rounds each amount half up before calculating and floors tax' do
        expect(invoice.plan_amount).to eq(101)
        expect(invoice.booth_amount).to eq(51)
        expect(invoice.approved_expense_amount).to eq(11)
        expect(invoice.subtotal).to eq(141)
        expect(invoice.tax).to eq(14)
        expect(invoice.total).to eq(155)
      end
    end

    context 'with expenses equal to the fees' do
      let(:expense_amount) { 350_000 }

      it 'allows zero-value invoices' do
        expect(invoice.subtotal).to eq(0)
        expect(invoice.tax).to eq(0)
        expect(invoice.total).to eq(0)
        expect(invoice).to be_exportable
      end
    end

    context 'with expenses exceeding the fees' do
      let(:expense_amount) { 350_001 }

      it 'keeps the full deduction and floors negative tax' do
        expect(invoice.approved_expense_amount).to eq(350_001)
        expect(invoice.subtotal).to eq(-1)
        expect(invoice.tax).to eq(-1)
        expect(invoice.total).to eq(-2)
        expect(invoice).not_to be_exportable
      end
    end

    context 'with negative expenses' do
      let(:expense_amount) { BigDecimal('-10.50') }

      it 'preserves the negative amount without correction' do
        expect(invoice.approved_expense_amount).to eq(-11)
        expect(invoice.subtotal).to eq(350_011)
      end
    end
  end

  context 'with an approved report on a non-customized sponsorship' do
    let(:expense_report) { instance_double(ExpenseReport, status: 'approved', total_amount: 100_000) }

    it 'does not deduct expenses' do
      expect(invoice.approved_expense_amount).to eq(0)
      expect(invoice.subtotal).to eq(350_000)
    end
  end
end
