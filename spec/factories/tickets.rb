FactoryBot.define do
  factory :ticket do
    conference
    sponsorship
    kind { :attendee }
    sequence(:name) { |n| "Attendee #{n}" }

    trait :booth_staff do
      kind { :booth_staff }
    end

    trait :checked_in do
      checked_in_at { Time.current }
    end
  end
end
