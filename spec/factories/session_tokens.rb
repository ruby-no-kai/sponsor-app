FactoryBot.define do
  factory :session_token do
    sequence(:email) { |n| "user#{n}@example.com" }
    expires_at { 3.months.from_now }

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :with_sponsorship do
      sponsorship
    end

    trait :with_staff do
      staff
    end
  end
end
