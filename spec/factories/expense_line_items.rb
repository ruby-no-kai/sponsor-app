# frozen_string_literal: true

FactoryBot.define do
  factory :expense_line_item do
    expense_report
    title { 'Test expense' }
    amount { 1000 }
    tax_rate { '0.1' }
    tax_amount { 100 }
    sequence(:position) { |n| n }
  end
end
