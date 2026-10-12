# typed: true
# frozen_string_literal: true

class ExpenseReportReview < ApplicationRecord
  belongs_to :expense_report_submission
  belongs_to :staff, optional: true

  validates :action, inclusion: {in: %w[approve reject]}
  validates :comment, presence: true, if: ->(review) { review.action == 'reject' }

  def self.create_for!(submission, action:, comment:, staff:)
    transaction do
      submission.review&.destroy!
      review = submission.create_review!(action:, comment:, staff:)
      report = Must.expect(submission.expense_report)
      report.status = action == 'approve' ? 'approved' : 'rejected'
      report.save!
      review
    end
  end
end
