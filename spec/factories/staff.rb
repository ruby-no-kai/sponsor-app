FactoryBot.define do
  factory :staff do
    sequence(:login) { |n| "orgz#{n}" }
    sequence(:name ) { |n| "Orgz #{n}" }
    sequence(:uid) { |n| "uid_#{n}" }
  end
end
