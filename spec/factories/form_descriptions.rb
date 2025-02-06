FactoryBot.define do
  factory :form_description do
    conference
    locale { "en" }
    head { "- Head #{locale} #{conference.id}" }
    plan_help { "- Plan #{locale} #{conference.id}" }
    booth_help { "- Booth #{locale} #{conference.id}" }
    policy_help { "- Policy #{locale} #{conference.id}" }
    ticket_help { "- Ticket #{locale} #{conference.id}" }
  end
end
