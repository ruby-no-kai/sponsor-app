# typed: strict
# frozen_string_literal: true

class ExpenseReportSubmission < ApplicationRecord
  belongs_to :expense_report
  has_one :review, class_name: 'ExpenseReportReview', dependent: :destroy

  #: () -> bool
  def reviewed?
    review.present?
  end
end
