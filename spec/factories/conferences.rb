FactoryBot.define do
  factory :conference do
    sequence(:name) { |n| "Conf #{n}" }
    sequence(:slug) { |n| "conf#{n}" }
    booth_capacity { 50 }
    sequence(:contact_email_address) { |n| "info+#{n}@conf.test.invalid" }

    trait :full do
      after(:create) do |conference, context|
        create(:form_description, conference:)
        create(:plan, conference:)
      end
    end
  end
end
