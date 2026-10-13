# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AdminService expense reports', type: :request do
  let(:staff) { FactoryBot.create(:staff) }
  let(:restricted_staff) { FactoryBot.create(:staff, restricted_repos: ['ruby-no-kai/rubykaigi-admitted']) }
  let(:conference) { FactoryBot.create(:conference) }
  let(:plan) { FactoryBot.create(:plan, conference:, name: 'Platinum', price: 3_000_000, price_booth: 500_000) }
  let(:sponsorship) do
    FactoryBot.create(:sponsorship, conference:, plan:, name: 'Acme', customization: true, customization_name: 'Acme Lounge',
      booth_assigned: true)
  end
  let!(:report) do
    FactoryBot.create(:expense_report, sponsorship:, status: 'submitted', revision: 1, total_amount: '120000', total_tax_amount: '12000')
  end

  describe 'ListExpenseReports' do
    let(:rpc) { connect_method('AdminService', 'ListExpenseReports') }

    def request_for(slug = conference.slug) = Rk::SponsorApp::AdminServiceListExpenseReportsRequest.new(conference_slug: slug)

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'lists custom sponsorships by name, with their reports in brief and the fee they offset' do
        FactoryBot.create(:sponsorship, conference:, plan:, name: 'Not custom', customization: false)
        FactoryBot.create(:sponsorship, conference: FactoryBot.create(:conference), plan: nil, name: 'Elsewhere', customization: true)
        no_report = FactoryBot.create(:sponsorship, conference:, plan: nil, name: 'Bespoke', customization: true)

        rows = connect_call(rpc, request_for).rows

        expect(rows.map { it.sponsorship.name }).to eq(['Acme', 'Bespoke'])
        expect(rows.first).to have_attributes(
          displayed_plan_name: 'Acme Lounge',
          total_fee: '3500000.0',
          report: Rk::SponsorApp::ExpenseReportTableRow::Report.new(
            status: :STATUS_SUBMITTED,
            total_amount: '120000.0',
            total_tax_amount: '12000.0',
            offset: '3380000.0',
          ),
        )
        expect(rows.first.sponsorship.id).to eq(sponsorship.id)
        expect(rows.last).to have_attributes(has_displayed_plan_name?: false, total_fee: '0', report: nil)
        expect(rows.last.sponsorship.id).to eq(no_report.id)
      end

      it 'answers a negative offset when the expenses exceed the fee' do
        report.update!(total_amount: '4000000')

        expect(connect_call(rpc, request_for).rows.sole.report.offset).to eq('-500000.0')
      end

      it 'answers GET, in JSON and binary, and binary POST alike' do
        expected = connect_call(rpc, request_for)

        expect(connect_call(rpc, request_for, via: :get)).to eq(expected)
        expect(connect_call(rpc, request_for, via: :get, codec: :proto)).to eq(expected)
        expect(connect_call(rpc, request_for, codec: :proto)).to eq(expected)
      end

      it 'reads as many queries however many sponsorships there are' do
        baseline = query_count { connect_call(rpc, request_for) }
        3.times do
          FactoryBot.create(:expense_report, sponsorship: FactoryBot.create(:sponsorship, conference:, plan:, customization: true))
        end

        expect(query_count { connect_call(rpc, request_for) }).to eq(baseline)
      end

      it 'answers not_found for an unknown conference' do
        expect(connect_call(rpc, request_for('nothing'))).to have_attributes(status: 404, code: 'not_found')
      end
    end

    it 'answers unauthenticated without a staff session' do
      expect(connect_call(rpc, request_for)).to have_attributes(status: 401, code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_for)).to have_attributes(status: 403, code: 'permission_denied')
    end
  end

  describe 'GetExpenseReport' do
    let(:rpc) { connect_method('AdminService', 'GetExpenseReport') }
    let!(:receipt) { FactoryBot.create(:expense_file, sponsorship:, filename: 'receipt.pdf', content_type: 'application/pdf') }
    let!(:invoice) { FactoryBot.create(:expense_file, sponsorship:, filename: nil, content_type: 'image/png') }

    def request_for(sponsorship_id = sponsorship.id, slug: conference.slug)
      Rk::SponsorApp::AdminServiceGetExpenseReportRequest.new(conference_slug: slug, sponsorship_id:)
    end

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'returns the report with its line items, uploaded files and latest review' do
        venue = FactoryBot.create(:expense_line_item, expense_report: report, title: 'Venue', notes: 'Hall A', amount: '100000',
          tax_rate: '0.1', position: 2)
        catering = FactoryBot.create(:expense_line_item, expense_report: report, title: 'Catering', notes: nil, amount: '20000',
          tax_rate: nil, tax_amount: '1500', preliminal: true, position: 1)
        venue.expense_line_item_files.create!(expense_file: invoice)
        venue.expense_line_item_files.create!(expense_file: receipt)
        FactoryBot.create(:expense_file, sponsorship:, status: 'pending')
        FactoryBot.create(:expense_file, sponsorship: FactoryBot.create(:sponsorship, conference:, plan:))
        submission = FactoryBot.create(:expense_report_submission, expense_report: report, revision: 1)
        review = FactoryBot.create(:expense_report_review, expense_report_submission: submission, action: 'reject', comment: 'Add receipts')

        response = connect_call(rpc, request_for)

        expect(response.sponsorship).to have_attributes(id: sponsorship.id, name: 'Acme')
        expect(response.report).to have_attributes(
          id: report.id,
          status: :STATUS_SUBMITTED,
          total_amount: '120000.0',
          total_tax_amount: '12000.0',
          revision: 1,
          created_at: Google::Protobuf::Timestamp.from_time(report.created_at),
          updated_at: Google::Protobuf::Timestamp.from_time(report.updated_at),
          latest_review: Rk::SponsorApp::ExpenseReportReview.new(
            action: :ACTION_REJECT,
            comment: 'Add receipts',
            created_at: Google::Protobuf::Timestamp.from_time(review.created_at),
          ),
        )
        expect(response.report.line_items.to_a).to eq([
          Rk::SponsorApp::ExpenseLineItem.new(
            id: catering.id, title: 'Catering', amount: '20000.0', tax_amount: '1500.0', preliminal: true, position: 1,
          ),
          Rk::SponsorApp::ExpenseLineItem.new(
            id: venue.id, title: 'Venue', notes: 'Hall A', amount: '100000.0', tax_rate: '0.1', tax_amount: '10000.0',
            preliminal: false, position: 2, file_ids: [invoice.id, receipt.id],
          ),
        ])
        expect(response.report.files.to_a).to eq([
          Rk::SponsorApp::ExpenseFile.new(
            id: receipt.id, filename: 'receipt.pdf', content_type: 'application/pdf',
            created_at: Google::Protobuf::Timestamp.from_time(receipt.created_at),
          ),
          Rk::SponsorApp::ExpenseFile.new(
            id: invoice.id, content_type: 'image/png', created_at: Google::Protobuf::Timestamp.from_time(invoice.created_at),
          ),
        ])
      end

      it 'leaves the latest review out until the latest submission is reviewed' do
        old = FactoryBot.create(:expense_report_submission, expense_report: report, revision: 1)
        FactoryBot.create(:expense_report_review, expense_report_submission: old)
        FactoryBot.create(:expense_report_submission, expense_report: report, revision: 2)

        expect(connect_call(rpc, request_for).report.latest_review).to be_nil
      end

      it 'answers GET, in JSON and binary, alike' do
        FactoryBot.create(:expense_line_item, expense_report: report, position: 1)
        expected = connect_call(rpc, request_for)

        expect(connect_call(rpc, request_for, via: :get)).to eq(expected)
        expect(connect_call(rpc, request_for, via: :get, codec: :proto)).to eq(expected)
      end

      it 'answers not_found for a sponsorship without a report' do
        bare = FactoryBot.create(:sponsorship, conference:, plan:, customization: true)

        expect(connect_call(rpc, request_for(bare.id))).to have_attributes(status: 404, code: 'not_found')
      end

      it 'answers not_found for a sponsorship of another conference' do
        other = FactoryBot.create(:sponsorship, conference: FactoryBot.create(:conference), plan: nil, customization: true)
        FactoryBot.create(:expense_report, sponsorship: other)

        expect(connect_call(rpc, request_for(other.id))).to have_attributes(status: 404, code: 'not_found')
      end

      it 'answers invalid_argument for a sponsorship ID that cannot exist' do
        expect(violations_of(connect_call(rpc, request_for(0)))).to eq([['sponsorshipId', 'INT64_GT']])
      end
    end

    it 'answers unauthenticated without a staff session' do
      expect(connect_call(rpc, request_for)).to have_attributes(status: 401, code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_for)).to have_attributes(status: 403, code: 'permission_denied')
    end
  end

  describe 'CalculateExpenseReport' do
    let(:rpc) { connect_method('AdminService', 'CalculateExpenseReport') }

    def request_for(sponsorship_id = sponsorship.id, slug: conference.slug)
      Rk::SponsorApp::AdminServiceCalculateExpenseReportRequest.new(conference_slug: slug, sponsorship_id:)
    end

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'returns the configured tax rates and the fee, booth included once assigned' do
        expect(connect_call(rpc, request_for).calculation).to eq(Rk::SponsorApp::ExpenseReportCalculation.new(
          tax_rates: ['0.1', '0.08', '0.0'],
          decimal: 0,
          plan_price: '3000000.0',
          plan_price_booth: '500000.0',
          booth_assigned: true,
          total_fee: '3500000.0',
        ))
      end

      it 'leaves the plan prices out while the plan is undetermined' do
        sponsorship.update!(plan: nil, booth_assigned: false)

        expect(connect_call(rpc, request_for).calculation).to have_attributes(
          has_plan_price?: false,
          has_plan_price_booth?: false,
          booth_assigned: false,
          total_fee: '0',
        )
      end

      it 'answers GET' do
        expect(connect_call(rpc, request_for, via: :get)).to eq(connect_call(rpc, request_for))
      end

      it 'answers not_found for a sponsorship of another conference' do
        other = FactoryBot.create(:sponsorship, conference: FactoryBot.create(:conference), plan: nil)

        expect(connect_call(rpc, request_for(other.id))).to have_attributes(status: 404, code: 'not_found')
      end
    end

    it 'answers unauthenticated without a staff session' do
      expect(connect_call(rpc, request_for)).to have_attributes(status: 401, code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_for)).to have_attributes(status: 403, code: 'permission_denied')
    end
  end
end
