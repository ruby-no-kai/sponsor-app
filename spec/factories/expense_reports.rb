# frozen_string_literal: true

FactoryBot.define do
  factory :expense_report do
    sponsorship { association(:sponsorship, customization: true) }
    status { 'draft' }
    revision { 0 }
  end
end
