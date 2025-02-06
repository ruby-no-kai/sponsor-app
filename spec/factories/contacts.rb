FactoryBot.define do
  factory :contact do
    #sponsorship
    kind { "primary" }
    sequence(:email) { |n|  "primary@#{n}.co.invalid" }
    sequence(:address) { |n|  "#{n}-#{n}-#{n}" }
    sequence(:organization) { |n| "Contoso" }
    sequence(:name) { |n| "User #{n}" }
  end
end
