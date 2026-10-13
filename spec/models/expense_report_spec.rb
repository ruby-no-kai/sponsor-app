# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExpenseReport, type: :model do
  let(:conference) { FactoryBot.create(:conference) }
  let(:plan) { FactoryBot.create(:plan, conference:) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:, customization: true) }

  describe 'validations' do
    it 'requires a custom sponsorship' do
      non_custom = FactoryBot.create(:sponsorship, conference:, plan:, customization: false)
      report = described_class.new(sponsorship: non_custom)
      expect(report).not_to be_valid
      expect(report.errors[:sponsorship]).to be_present
    end

    it 'allows a custom sponsorship' do
      report = described_class.new(sponsorship:)
      expect(report).to be_valid
    end

    it 'enforces one report per sponsorship' do
      described_class.create!(sponsorship:)
      duplicate = described_class.new(sponsorship:)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:sponsorship_id]).to be_present
    end
  end

  describe '#recalculate_totals' do
    it 'sums line items' do
      report = FactoryBot.create(:expense_report, sponsorship:)
      FactoryBot.create(:expense_line_item, expense_report: report, amount: 1000, tax_amount: 100, position: 1)
      FactoryBot.create(:expense_line_item, expense_report: report, amount: 2000, tax_amount: 200, position: 2)
      report.reload

      report.recalculate_totals
      expect(report.total_amount).to eq(3000)
      expect(report.total_tax_amount).to eq(300)
    end

    it 'does not save' do
      report = FactoryBot.create(:expense_report, sponsorship:)
      FactoryBot.create(:expense_line_item, expense_report: report, amount: 1000, tax_amount: 100, position: 1)
      report.reload

      report.recalculate_totals
      expect(report).to be_changed
    end

    it 'sums to zero for an unsaved report' do
      report = described_class.new(sponsorship:)

      report.recalculate_totals
      expect(report.total_amount).to eq(0)
      expect(report.total_tax_amount).to eq(0)
    end
  end

  describe '#submit!' do
    let(:report) { FactoryBot.create(:expense_report, sponsorship:) }

    before do
      FactoryBot.create(:expense_line_item, expense_report: report, amount: 500, tax_amount: 50, position: 1)
    end

    it 'transitions from draft to submitted' do
      report.submit!
      expect(report.status).to eq('submitted')
    end

    it 'increments revision' do
      report.submit!
      expect(report.revision).to eq(1)
    end

    it 'creates a submission with snapshot' do
      expect { report.submit! }.to change(ExpenseReportSubmission, :count).by(1)
      submission = report.current_submission
      expect(submission.revision).to eq(1)
      expect(submission.data).to have_attributes(id: report.id, status: 'submitted', revision: 1, total_amount: '0.0', total_tax_amount: '0.0')
      expect(submission.data.line_items.size).to eq(1)
    end

    it 'raises when not draft' do
      report.submit!
      expect { report.submit! }.to raise_error(RuntimeError, /Cannot submit/)
    end
  end

  describe '#withdraw_submission!' do
    it 'transitions from submitted to draft' do
      report = FactoryBot.create(:expense_report, sponsorship:, status: 'submitted')
      report.withdraw_submission!
      expect(report.status).to eq('draft')
    end

    it 'raises when not submitted' do
      report = FactoryBot.create(:expense_report, sponsorship:, status: 'draft')
      expect { report.withdraw_submission! }.to raise_error(RuntimeError, /Cannot withdraw/)
    end
  end

  describe '#reopen_if_rejected' do
    it 'transitions from rejected to draft' do
      report = FactoryBot.create(:expense_report, sponsorship:, status: 'rejected')
      report.reopen_if_rejected
      expect(report.status).to eq('draft')
    end

    it 'does nothing when draft' do
      report = FactoryBot.create(:expense_report, sponsorship:, status: 'draft')
      report.reopen_if_rejected
      expect(report.status).to eq('draft')
    end

    it 'does nothing when submitted' do
      report = FactoryBot.create(:expense_report, sponsorship:, status: 'submitted')
      report.reopen_if_rejected
      expect(report.status).to eq('submitted')
    end

    it 'does not save' do
      report = FactoryBot.create(:expense_report, sponsorship:, status: 'rejected')
      report.reopen_if_rejected
      expect(report).to be_changed
    end
  end

  describe '#build_snapshot_data' do
    it 'snapshots the report and its line items in position order' do
      report = FactoryBot.create(:expense_report, sponsorship:, total_amount: 1500, total_tax_amount: 100)
      file = FactoryBot.create(:expense_file, sponsorship:)
      novelty = FactoryBot.create(:expense_line_item, expense_report: report, title: 'Novelty', notes: 'Exempt', amount: 500, tax_rate: nil, tax_amount: 0, preliminal: true, position: 2)
      booth = FactoryBot.create(:expense_line_item, expense_report: report, title: 'Booth', amount: 1000, tax_rate: '0.1', position: 1)
      booth.expense_line_item_files.create!(expense_file: file)

      expect(report.reload.build_snapshot_data).to eq(Rk::SponsorApp::Internal::ExpenseReportSnapshot.new(
        id: report.id,
        status: 'draft',
        total_amount: '1500.0',
        total_tax_amount: '100.0',
        revision: 0,
        line_items: [
          Rk::SponsorApp::Internal::ExpenseReportSnapshot::LineItem.new(
            id: booth.id, title: 'Booth', amount: '1000.0', tax_rate: '0.1', tax_amount: '100.0', preliminal: false, position: 1, file_ids: [file.id],
          ),
          Rk::SponsorApp::Internal::ExpenseReportSnapshot::LineItem.new(
            id: novelty.id, title: 'Novelty', notes: 'Exempt', amount: '500.0', tax_amount: '0.0', preliminal: true, position: 2,
          ),
        ],
      ))
    end
  end

  describe '#refresh_submission_snapshot' do
    it 'updates current submission data when submitted' do
      report = FactoryBot.create(:expense_report, sponsorship:)
      FactoryBot.create(:expense_line_item, expense_report: report, amount: 500, tax_amount: 50, position: 1)
      report.submit!

      FactoryBot.create(:expense_line_item, expense_report: report, amount: 1000, tax_amount: 100, position: 2)
      report.reload
      report.refresh_submission_snapshot

      submission = report.current_submission.reload
      expect(submission.data.line_items.map(&:amount)).to eq(['500.0', '1000.0'])
    end

    it 'does nothing when draft' do
      report = FactoryBot.create(:expense_report, sponsorship:, status: 'draft')
      report.refresh_submission_snapshot
      expect(report.submissions).to be_empty
    end
  end

  describe '#latest_review' do
    it 'returns the review of the current submission' do
      report = FactoryBot.create(:expense_report, sponsorship:)
      report.submit!
      submission = report.current_submission
      staff = FactoryBot.create(:staff)
      ExpenseReportReview.create_for!(submission, action: 'approve', comment: nil, staff:)

      expect(report.reload.latest_review).to be_present
      expect(report.latest_review.action).to eq('approve')
    end
  end
end
