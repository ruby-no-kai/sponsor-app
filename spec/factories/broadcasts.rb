# frozen_string_literal: true

FactoryBot.define do
  factory :broadcast do
    conference
    staff
    status { :created }
    sequence(:campaign) { |n| "Campaign #{n}" }
    sequence(:description, &:to_s)
    sequence(:title) { |n| "Email #{n}" }
    sequence(:body) { |n| "- Email #{n}" }
  end
end
