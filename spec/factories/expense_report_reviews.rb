# frozen_string_literal: true

FactoryBot.define do
  factory :expense_report_review do
    expense_report_submission
    staff
    action { 'approve' }
    comment { nil }
  end
end
