FactoryBot.define do
  factory :tito_discount_code do
    sponsorship
    sequence(:code) { |n| "SPONSOR#{n}" }
    sequence(:tito_discount_code_id) { |n| "tito_dc_#{n}" }
    kind { :attendee }
  end
end
