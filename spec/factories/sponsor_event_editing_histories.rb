FactoryBot.define do
  factory :sponsor_event_editing_history do
    sponsor_event
    raw { sponsor_event&.to_h_for_history || {} }
  end
end
