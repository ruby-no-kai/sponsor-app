# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MoneyForwardInvoiceCsv do
  subject(:invoice_csv) do
    described_class.new(
      conference:,
      sponsorships:,
      invoice_date: Date.new(2026, 8, 16),
      delivery_date: Date.new(2026, 10, 3),
      starting_invoice_number:,
    )
  end

  let(:starting_invoice_number) { 1 }
  let(:excluded_rows) { invoice_csv.excluded_rows.map { |row| invoice_csv.headers.zip(row).to_h } }
  let(:excluded_invoice) { excluded_rows.find { |row| row.fetch('行形式') == '請求書' } }

  let(:csv_rows) { CSV.parse(invoice_csv.to_csv, headers: true).map(&:to_h) }
  let(:expected_csv) { file_fixture('money_forward_invoice_csv/with_booth.csv').read }
  let(:expected_rows) { CSV.parse(expected_csv, headers: true).map(&:to_h) }
  let(:expected_invoice) { expected_rows.find { |row| row.fetch('行形式') == '請求書' } }
  let(:expected_plan_item) { expected_rows.find { |row| row.fetch('品名') == 'RubyKaigi YYYY 協賛費用 (Ruby)' } }
  let(:expected_booth_item) { expected_rows.find { |row| row.fetch('品名') == 'RubyKaigi YYYY 協賛費用 (ブース出展)' } }

  let(:sponsorships) { [sponsorship] }
  let(:conference) { instance_double(Conference, name: 'RubyKaigi YYYY') }
  let(:contact) do
    instance_double(
      Contact,
      organization: '株式会社Ruby',
      address: '東京都千代田区1-1',
      unit: '技術部',
      name: '山田太郎',
    )
  end
  let(:plan) { instance_double(Plan, name: 'Ruby', price: 300_000, price_booth: 50_000) }
  let(:sponsorship) do
    instance_double(Sponsorship, billing_contact: contact, plan:, booth_assigned: true, customization: false, expense_report: nil)
  end

  describe '#to_csv' do
    it 'exports the complete Money Forward CSV' do
      expect(invoice_csv.to_csv).to eq(expected_csv)
    end

    it 'uses CRLF line endings required by the import format' do
      expect(invoice_csv.to_csv).to end_with("\r\n")
      expect(invoice_csv.to_csv.gsub("\r\n", "")).not_to include("\n", "\r")
    end

    context 'without a booth' do
      let(:sponsorship) do
        instance_double(Sponsorship, billing_contact: contact, plan:, booth_assigned: false, customization: false, expense_report: nil)
      end

      it 'does not add booth price or a booth item' do
        expect(csv_rows).to eq([
          expected_invoice.merge('小計' => '300000', '消費税' => '30000', '合計金額' => '330000'),
          expected_plan_item,
        ])
      end
    end

    context 'with fractional decimal amounts' do
      let(:plan) { instance_double(Plan, name: 'Ruby', price: 300_000.49.to_d, price_booth: 50_000.50.to_d) }

      it 'rounds monetary output to integer yen before calculating invoice tax' do
        expect(csv_rows).to eq([
          expected_invoice.merge('小計' => '350001', '合計金額' => '385001'),
          expected_plan_item,
          expected_booth_item.merge('単価' => '50001', '金額' => '50001'),
        ])
      end
    end

    context 'with an approved expense report for a custom sponsorship' do
      let(:expense_report) { instance_double(ExpenseReport, status: 'approved', total_amount: 100_000) }
      let(:sponsorship) do
        instance_double(Sponsorship, billing_contact: contact, plan:, booth_assigned: true, customization: true, expense_report:)
      end

      it 'adds the approved expense as the final negative item' do
        expect(invoice_csv.to_csv).to eq(file_fixture('money_forward_invoice_csv/custom_sponsorship.csv').read)
      end
    end

    context 'with a negative expense amount' do
      let(:expense_report) { instance_double(ExpenseReport, status: 'approved', total_amount: -100) }
      let(:sponsorship) do
        instance_double(Sponsorship, billing_contact: contact, plan:, booth_assigned: true, customization: true, expense_report:)
      end

      it 'adds no deduction item while preserving the calculated subtotal' do
        expect(csv_rows).to eq([
          expected_invoice.merge('小計' => '350100', '消費税' => '35010', '合計金額' => '385110'),
          expected_plan_item,
          expected_booth_item,
        ])
      end
    end

    context 'when approved expenses exceed the sponsorship fee' do
      let(:expense_report) { instance_double(ExpenseReport, status: 'approved', total_amount: 400_000) }
      let(:sponsorship) do
        instance_double(Sponsorship, billing_contact: contact, plan:, booth_assigned: false, customization: true, expense_report:)
      end

      let(:excluded_custom_item) { excluded_rows.find { |row| row.fetch('品名') == 'カスタムスポンサー費用分' } }

      it 'excludes the invoice from the CSV' do
        expect(CSV.parse(invoice_csv.to_csv)).to eq([described_class::COLUMNS.values])
      end

      it 'separates the negative invoice from exported rows without capping the deduction' do
        expect(invoice_csv.rows).to eq([])
        expect(excluded_invoice).to include(
          '請求書番号' => nil, '小計' => -100_000, '消費税' => -10_000, '合計金額' => -110_000,
        )
        expect(excluded_custom_item).to include(
          '品名' => 'カスタムスポンサー費用分', '単価' => -400_000, '金額' => -400_000,
        )
      end
    end

    context 'when approved expenses equal the sponsorship fee' do
      let(:expense_report) { instance_double(ExpenseReport, status: 'approved', total_amount: 300_000) }
      let(:sponsorship) do
        instance_double(Sponsorship, billing_contact: contact, plan:, booth_assigned: false, customization: true, expense_report:)
      end

      it 'keeps the zero-value invoice in exported rows' do
        expect(csv_rows.size).to eq(3)
        expect(csv_rows.first).to eq(expected_invoice.merge('小計' => '0', '消費税' => '0', '合計金額' => '0'))
        expect(csv_rows.last).to include('品名' => 'カスタムスポンサー費用分', '単価' => '-300000', '金額' => '-300000')
        expect(invoice_csv.excluded_rows).to eq([])
      end
    end
  end

  context 'with no sponsorships' do
    let(:sponsorships) { [] }

    it 'exports only the header' do
      expect(invoice_csv.rows).to eq([])
      expect(invoice_csv.excluded_rows).to eq([])
      expect(invoice_csv).not_to be_exportable
      expect(CSV.parse(invoice_csv.to_csv)).to eq([described_class::COLUMNS.values])
    end
  end

  context 'with an excluded invoice between exportable invoices' do
    let(:expense_report) { instance_double(ExpenseReport, status: 'approved', total_amount: 400_000) }
    let(:excluded_sponsorship) do
      instance_double(Sponsorship, billing_contact: contact, plan:, booth_assigned: false, customization: true, expense_report:)
    end
    let(:sponsorships) { [sponsorship, excluded_sponsorship, sponsorship] }

    it 'numbers only exported invoices and leaves excluded numbers blank' do
      expect(csv_rows).to eq([
        *expected_rows,
        expected_invoice.merge('請求書番号' => '20260816-002'),
        expected_plan_item,
        expected_booth_item,
      ])
      expect(excluded_invoice.fetch('請求書番号')).to be_nil
    end
  end

  context 'with a specified starting invoice number' do
    let(:starting_invoice_number) { 42 }

    it 'uses the specified number with zero padding' do
      expect(invoice_csv.to_csv).to eq(expected_csv.sub('20260816-001', '20260816-042'))
    end
  end
end
