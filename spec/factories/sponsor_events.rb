FactoryBot.define do
  factory :sponsor_event do
    sponsorship
    sequence(:title) { |n| "Event #{n}" }
    starts_at { 1.week.from_now }
    sequence(:url) { |n| "https://example#{n}.com/event" }
    policy_acknowledged_at { Time.current }

    trait :pending do
      status { :pending }
    end

    trait :accepted do
      status { :accepted }
    end

    trait :rejected do
      status { :rejected }
    end

    trait :withdrawn do
      status { :withdrawn }
    end

    trait :with_details do
      price { 'Free' }
      capacity { '100 people' }
      location_en { 'Tokyo' }
      location_local { '東京' }
    end
  end
end
