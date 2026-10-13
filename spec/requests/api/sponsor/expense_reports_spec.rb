# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SponsorService expense reports', type: :request do
  let(:conference) { FactoryBot.create(:conference) }
  let(:plan) { FactoryBot.create(:plan, conference:, name: 'Platinum', price: 3_000_000, price_booth: 500_000) }
  let(:sponsorship) do
    FactoryBot.create(:sponsorship, conference:, plan:, customization: true, customization_name: 'Acme Lounge', booth_assigned: true)
  end

  def request_for(klass, slug: conference.slug) = klass.new(conference_slug: slug)

  shared_examples 'an RPC for custom sponsorships' do
    it 'answers unauthenticated without a sponsor session' do
      expect(connect_call(rpc, rpc_request)).to have_attributes(status: 401, code: 'unauthenticated')
    end

    it 'answers not_found for a conference the sponsor has no sponsorship in' do
      sign_in_sponsor(sponsorship.contact.email)

      expect(connect_call(rpc, rpc_request(slug: FactoryBot.create(:conference).slug))).to have_attributes(status: 404, code: 'not_found')
    end

    it 'answers permission_denied to a sponsorship that is not custom' do
      sponsorship.update!(customization: false)
      sign_in_sponsor(sponsorship.contact.email)

      expect(connect_call(rpc, rpc_request)).to have_attributes(status: 403, code: 'permission_denied')
    end

    it 'answers permission_denied to a sponsorship planning a custom package that is not confirmed' do
      sponsorship.update!(customization: false, customization_name: 'Acme Lounge')
      sign_in_sponsor(sponsorship.contact.email)

      expect(connect_call(rpc, rpc_request)).to have_attributes(status: 403, code: 'permission_denied')
    end
  end

  describe 'GetExpenseReport' do
    let(:rpc) { connect_method('SponsorService', 'GetExpenseReport') }

    def rpc_request(slug: conference.slug) = request_for(Rk::SponsorApp::SponsorServiceGetExpenseReportRequest, slug:)

    it_behaves_like 'an RPC for custom sponsorships'

    context 'with a sponsor session' do
      before { sign_in_sponsor(sponsorship.contact.email) }

      it 'answers not_found before the sponsor starts a report' do
        expect(connect_call(rpc, rpc_request)).to have_attributes(status: 404, code: 'not_found')
      end

      it 'returns the report with its line items, uploaded files and latest review, decimals as strings' do
        report = FactoryBot.create(:expense_report, sponsorship:, status: 'rejected', revision: 1, total_amount: '120000', total_tax_amount: '12000')
        receipt = FactoryBot.create(:expense_file, sponsorship:, filename: 'receipt.pdf', content_type: 'application/pdf')
        item = FactoryBot.create(:expense_line_item, expense_report: report, title: 'Venue', amount: '100000', tax_rate: '0.1')
        item.expense_line_item_files.create!(expense_file: receipt)
        FactoryBot.create(:expense_file, sponsorship:, status: 'pending')
        FactoryBot.create(:expense_file, sponsorship: FactoryBot.create(:sponsorship, conference:, plan:, customization: true))
        submission = FactoryBot.create(:expense_report_submission, expense_report: report, revision: 1)
        FactoryBot.create(:expense_report_review, expense_report_submission: submission, action: 'reject', comment: 'Add receipts')

        result = connect_call(rpc, rpc_request).report

        expect(result).to have_attributes(
          id: report.id, status: :STATUS_REJECTED, total_amount: '120000.0', total_tax_amount: '12000.0', revision: 1,
        )
        expect(result.line_items.map { [it.title, it.amount, it.tax_rate, it.file_ids.to_a] }).to eq([['Venue', '100000.0', '0.1', [receipt.id]]])
        expect(result.files.map(&:id)).to eq([receipt.id])
        expect(result.latest_review).to have_attributes(action: :ACTION_REJECT, comment: 'Add receipts')
      end

      it 'answers GET and binary POST alike' do
        FactoryBot.create(:expense_report, sponsorship:)
        expected = connect_call(rpc, rpc_request)

        expect(connect_call(rpc, rpc_request, via: :get)).to eq(expected)
        expect(connect_call(rpc, rpc_request, codec: :proto)).to eq(expected)
      end

      it 'never shows the report of another sponsorship' do
        FactoryBot.create(:expense_report, sponsorship: FactoryBot.create(:sponsorship, conference:, plan:, customization: true))

        expect(connect_call(rpc, rpc_request)).to have_attributes(status: 404, code: 'not_found')
      end
    end
  end

  describe 'CalculateExpenseReport' do
    let(:rpc) { connect_method('SponsorService', 'CalculateExpenseReport') }

    def rpc_request(slug: conference.slug) = request_for(Rk::SponsorApp::SponsorServiceCalculateExpenseReportRequest, slug:)

    it_behaves_like 'an RPC for custom sponsorships'

    context 'with a sponsor session' do
      before { sign_in_sponsor(sponsorship.contact.email) }

      it 'returns the rates, rounding and fees, the booth fee added when a booth is assigned' do
        calculation = connect_call(rpc, rpc_request).calculation

        expect(calculation).to have_attributes(
          tax_rates: ['0.1', '0.08', '0.0'],
          decimal: Rails.configuration.x.expense_report.decimal,
          plan_price: '3000000.0',
          plan_price_booth: '500000.0',
          booth_assigned: true,
          total_fee: '3500000.0',
        )
      end

      it 'leaves the booth fee out without a booth' do
        sponsorship.update!(booth_assigned: false)

        expect(connect_call(rpc, rpc_request).calculation).to have_attributes(booth_assigned: false, total_fee: '3000000.0')
      end

      it 'answers a fee of 0 without a plan' do
        sponsorship.update!(plan: nil)

        expect(connect_call(rpc, rpc_request).calculation).to have_attributes(has_plan_price?: false, total_fee: '0')
      end

      it 'answers GET' do
        expect(connect_call(rpc, rpc_request, via: :get)).to eq(connect_call(rpc, rpc_request))
      end
    end
  end

  describe 'CreateExpenseReport' do
    let(:rpc) { connect_method('SponsorService', 'CreateExpenseReport') }

    def rpc_request(slug: conference.slug) = request_for(Rk::SponsorApp::SponsorServiceCreateExpenseReportRequest, slug:)

    it_behaves_like 'an RPC for custom sponsorships'

    context 'with a sponsor session' do
      before { sign_in_sponsor(sponsorship.contact.email) }

      it 'starts a draft report' do
        report = connect_call(rpc, rpc_request).report

        expect(report).to have_attributes(status: :STATUS_DRAFT, total_amount: '0.0', revision: 0)
        expect(sponsorship.reload.expense_report).to have_attributes(id: report.id, status: 'draft')
      end

      it 'answers the report it has, unchanged, when called again' do
        existing = FactoryBot.create(:expense_report, sponsorship:, status: 'rejected', revision: 2)

        expect(connect_call(rpc, rpc_request).report).to have_attributes(id: existing.id, status: :STATUS_REJECTED, revision: 2)
        expect(ExpenseReport.count).to eq(1)
      end

      it 'answers the report a concurrent call started first' do
        winner = FactoryBot.create(:expense_report, sponsorship:)
        allow(ExpenseReport).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)
        allow_any_instance_of(Sponsorship).to receive(:expense_report).and_return(nil, winner) # rubocop:disable RSpec/AnyInstance

        expect(connect_call(rpc, rpc_request).report.id).to eq(winner.id)
      end
    end
  end
end
