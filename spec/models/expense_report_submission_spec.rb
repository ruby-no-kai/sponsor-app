# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExpenseReportSubmission, type: :model do
  let(:conference) { FactoryBot.create(:conference) }
  let(:plan) { FactoryBot.create(:plan, conference:) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:, customization: true) }
  let(:report) { FactoryBot.create(:expense_report, sponsorship:) }

  describe '#reviewed?' do
    it 'returns false when no review exists' do
      submission = FactoryBot.create(:expense_report_submission, expense_report: report)
      expect(submission.reviewed?).to be false
    end

    it 'returns true when a review exists' do
      submission = FactoryBot.create(:expense_report_submission, expense_report: report)
      staff = FactoryBot.create(:staff)
      ExpenseReportReview.create_for!(submission, action: 'approve', comment: nil, staff:)
      expect(submission.reload.reviewed?).to be true
    end
  end
end
