# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SponsorService expense report submissions', type: :request do
  let(:conference) { FactoryBot.create(:conference) }
  let(:plan) { FactoryBot.create(:plan, conference:) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:, name: 'Acme', customization: true) }
  let!(:report) { FactoryBot.create(:expense_report, sponsorship:, total_amount: '1000', total_tax_amount: '100') }

  before do
    allow(SlackWebhookJob).to receive(:perform_later)
    sign_in_sponsor(sponsorship.contact.email)
  end

  describe 'SubmitExpenseReport' do
    let(:rpc) { connect_method('SponsorService', 'SubmitExpenseReport') }
    let(:rpc_request) { Rk::SponsorApp::SponsorServiceSubmitExpenseReportRequest.new(conference_slug: conference.slug) }

    it 'submits a draft, snapshotting it, and tells the organizers' do
      FactoryBot.create(:expense_line_item, expense_report: report, title: 'Venue', amount: '1000')

      result = connect_call(rpc, rpc_request).report

      expect(result).to have_attributes(status: :STATUS_SUBMITTED, revision: 1)
      expect(report.reload.submissions.sole.data.line_items.map(&:title)).to eq(['Venue'])
      expect(SlackWebhookJob).to have_received(:perform_later).with(
        {text: a_string_including('Acme submitted', 'expense report', '1000.0 + 100.0 tax')}, hook_name: :feed,
      )
    end

    it 'counts the revision up on each submission' do
      report.update!(status: 'draft', revision: 1)

      expect(connect_call(rpc, rpc_request).report.revision).to eq(2)
    end

    %w[submitted approved rejected].each do |status|
      it "answers failed_precondition for a #{status} report, telling nobody" do
        report.update!(status:)

        error = connect_call(rpc, rpc_request)

        expect(error).to have_attributes(status: 400, code: 'failed_precondition')
        expect(problem_type_of(error)).to eq('failed-precondition')
        expect(report.reload.status).to eq(status)
        expect(report.submissions).to be_empty
        expect(SlackWebhookJob).not_to have_received(:perform_later)
      end
    end

    it 'answers not_found before the sponsor starts a report' do
      report.destroy!

      expect(connect_call(rpc, rpc_request)).to have_attributes(status: 404, code: 'not_found')
    end

    it 'answers permission_denied to a sponsorship that is not custom' do
      sponsorship.update!(customization: false)

      expect(connect_call(rpc, rpc_request)).to have_attributes(status: 403, code: 'permission_denied')
      expect(report.reload.status).to eq('draft')
    end

    it 'answers unauthenticated without a sponsor session' do
      reset!

      expect(connect_call(rpc, rpc_request)).to have_attributes(status: 401, code: 'unauthenticated')
    end
  end

  describe 'WithdrawExpenseReportSubmission' do
    let(:rpc) { connect_method('SponsorService', 'WithdrawExpenseReportSubmission') }
    let(:rpc_request) { Rk::SponsorApp::SponsorServiceWithdrawExpenseReportSubmissionRequest.new(conference_slug: conference.slug) }

    it 'makes a submitted report a draft again' do
      report.update!(status: 'submitted', revision: 1)

      expect(connect_call(rpc, rpc_request).report).to have_attributes(status: :STATUS_DRAFT, revision: 1)
      expect(report.reload.status).to eq('draft')
    end

    %w[draft approved rejected].each do |status|
      it "answers failed_precondition for a #{status} report" do
        report.update!(status:)

        expect(connect_call(rpc, rpc_request)).to have_attributes(status: 400, code: 'failed_precondition')
        expect(report.reload.status).to eq(status)
      end
    end

    it 'answers permission_denied to a sponsorship that is not custom' do
      report.update!(status: 'submitted')
      sponsorship.update!(customization: false)

      expect(connect_call(rpc, rpc_request)).to have_attributes(status: 403, code: 'permission_denied')
    end
  end
end
