FactoryBot.define do
  factory :plan do
    conference
    sequence(:name) { |n| "Plan #{n}" }
    sequence(:rank) { |n| n }
    summary { "na" }
    capacity { 10 }
    number_of_guests { 1 }
    price_text { "na" }
    words_limit { 15 }
    auto_acceptance { true }
  end
end
