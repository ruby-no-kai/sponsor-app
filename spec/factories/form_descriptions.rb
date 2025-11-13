FactoryBot.define do
  factory :form_description do
    conference
    locale { "en" }
    head { conference ? "- Head #{locale} #{conference.id}" : "- Head #{locale}" }
    plan_help { conference ? "- Plan #{locale} #{conference.id}" : "- Plan #{locale}" }
    booth_help { conference ? "- Booth #{locale} #{conference.id}" : "- Booth #{locale}" }
    policy_help { conference ? "- Policy #{locale} #{conference.id}" : "- Policy #{locale}" }
    ticket_help { conference ? "- Ticket #{locale} #{conference.id}" : "- Ticket #{locale}" }
  end
end
