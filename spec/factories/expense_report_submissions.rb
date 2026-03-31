# frozen_string_literal: true

FactoryBot.define do
  factory :expense_report_submission do
    expense_report
    revision { 1 }
    data { {} }
  end
end
