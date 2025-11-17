FactoryBot.define do
  factory :sponsorship do
    conference
    plan { Plan.first }
    locale { 'en' }
    sequence(:name) { |n| "Contoso #{n}" }
    sequence(:url) { |n|  "https://#{n}.co.invalid" }
    sequence(:profile) { |n| "we're #{n}" }
    asset_file { association(:sponsorship_asset_file, sponsorship: nil) }

    after(:build) do |instance, ctx|
      instance.contact = FactoryBot.build(:contact, sponsorship: nil)
      instance.assume_organization
    end
  end
end
