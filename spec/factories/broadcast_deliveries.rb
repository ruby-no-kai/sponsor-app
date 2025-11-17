FactoryBot.define do
  factory :broadcast_delivery do
    broadcast
    sequence(:recipient) { |n| "recipient#{n}@example.com" }
    status { :created }

    trait :with_sponsorship do
      sponsorship
    end

    trait :sent do
      status { :sent }
    end

    trait :delivered do
      status { :delivered }
    end

    trait :with_cc do
      recipient_cc { "cc1@example.com, cc2@example.com" }
    end
  end
end
