# frozen_string_literal: true

FactoryBot.define do
  factory :contact do
    # sponsorship
    kind { "primary" }
    sequence(:email) { |n| "primary@#{n}.co.invalid" }
    sequence(:address) { |n|  "#{n}-#{n}-#{n}" }
    sequence(:organization) { |_n| "Contoso" }
    sequence(:name) { |n| "User #{n}" }
  end
end
