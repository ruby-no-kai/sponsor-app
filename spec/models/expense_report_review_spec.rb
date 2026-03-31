# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExpenseReportReview, type: :model do
  let(:conference) { FactoryBot.create(:conference) }
  let(:plan) { FactoryBot.create(:plan, conference:) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:, customization: true) }
  let(:staff) { FactoryBot.create(:staff) }

  describe 'validations' do
    it 'requires action to be approve or reject' do
      submission = FactoryBot.create(:expense_report_submission, expense_report: FactoryBot.create(:expense_report, sponsorship:))
      review = described_class.new(expense_report_submission: submission, action: 'invalid', staff:)
      expect(review).not_to be_valid
      expect(review.errors[:action]).to be_present
    end

    it 'requires comment when rejecting' do
      submission = FactoryBot.create(:expense_report_submission, expense_report: FactoryBot.create(:expense_report, sponsorship:))
      review = described_class.new(expense_report_submission: submission, action: 'reject', staff:, comment: nil)
      expect(review).not_to be_valid
      expect(review.errors[:comment]).to be_present
    end

    it 'does not require comment when approving' do
      submission = FactoryBot.create(:expense_report_submission, expense_report: FactoryBot.create(:expense_report, sponsorship:))
      review = described_class.new(expense_report_submission: submission, action: 'approve', staff:)
      expect(review).to be_valid
    end
  end

  describe '.create_for!' do
    let(:report) { FactoryBot.create(:expense_report, sponsorship:) }

    before do
      report.submit!
    end

    it 'creates a review and approves the report' do
      submission = report.current_submission
      review = described_class.create_for!(submission, action: 'approve', comment: nil, staff:)

      expect(review).to be_persisted
      expect(report.reload.status).to eq('approved')
    end

    it 'creates a review and rejects the report' do
      submission = report.current_submission
      review = described_class.create_for!(submission, action: 'reject', comment: 'Needs receipts', staff:)

      expect(review).to be_persisted
      expect(report.reload.status).to eq('rejected')
    end

    it 'raises on invalid action' do
      submission = report.current_submission
      expect do
        described_class.create_for!(submission, action: 'invalid', comment: nil, staff:)
      end.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end
