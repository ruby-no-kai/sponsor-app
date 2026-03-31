# frozen_string_literal: true

FactoryBot.define do
  factory :expense_file do
    sponsorship
    prefix { "c-1/expenses/s-1/" }
    filename { 'receipt.pdf' }
    content_type { 'application/pdf' }
    status { 'uploaded' }
  end
end
