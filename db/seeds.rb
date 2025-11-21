# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).

require "securerandom"
require 'jsonnet'

puts "Creating Conferences..."

sponsorship_id_base = SecureRandom.random_number(1000..9999) * 1000
sponsorship_id_next = -> { sponsorship_id_base += 1; sponsorship_id_base }

contact_emails = {}
generate_contact_email = ->(domain) {
  contact_emails[domain] ||= Faker::Internet.email(domain:)
}

ApplicationRecord.transaction do
  conferences = [
    {
      id: sponsorship_id_base + 1,
      name: "RubyKaigi 2048",
      contact_email_address: "2048@rubykaigi.invalid",
      tito_slug: nil,
      application_opens_at: Time.zone.now - 1.month - 1.year,
      application_closes_at: Time.zone.now + 1.month - 1.year,
      amendment_closes_at: Time.zone.now + 2.months,
      ticket_distribution_starts_at: Time.zone.now - 1.day - 1.year,
      booth_capacity: 50,
      github_repo: nil,
      hidden: false,
    },
    {
      id: sponsorship_id_base + 2,
      name: "RubyKaigi 4096",
      contact_email_address: "4096@rubykaigi.invalid",
      tito_slug: nil,
      application_opens_at: Time.zone.now - 1.month,
      application_closes_at: Time.zone.now + 1.month,
      amendment_closes_at: Time.zone.now + 2.months,
      ticket_distribution_starts_at: Time.zone.now - 1.day,
      booth_capacity: 50,
      github_repo: nil,
      hidden: false,
    }
  ]

  conferences.each do |conf_params|
    conference = Conference.find_or_initialize_by(name: conf_params[:name])
    conference.update!(conf_params)

    # Plans
    puts "Creating plans for #{conference.name}..."
    [
      {
        name: "Ruby",
        rank: 0,
        price_text: "2,000,000 JPY",
        words_limit: 200,
        booth_size: 2,
        capacity: 6,
        number_of_guests: 8,
        auto_acceptance: false,
        closes_at: Time.now + 30.days
      },
      {
        name: "Platinum",
        rank: 1,
        price_text: "1,000,000 JPY",
        words_limit: 100,
        booth_size: 1,
        capacity: 30,
        number_of_guests: 4,
        auto_acceptance: false,
        closes_at: Time.now + 30.days
      },
      {
        name: "Gold",
        rank: 2,
        price_text: "500,000 JPY",
        words_limit: 50,
        booth_size: nil,
        number_of_guests: 2,
        capacity: 1000,
      },
      {
        name: "Silver",
        rank: 3,
        price_text: "250,000 JPY",
        words_limit: 25,
        booth_size: nil,
        number_of_guests: 1,
        capacity: 10000,
      }
    ].each do |plan_params|
      conference.plans.find_or_create_by!(plan_params)
    end

    # FormDescriptions
    puts "Creating form_descriptions for #{conference.name}..."
    [
      {
        locale: "en",
        head: "Thank you for your interest in sponsoring #{conference.name}. Please fill in the information for the main contact, invoice details, and your company information.",
        plan_help: "See the sponsorship prospectus for package details.",
        booth_help: "Sponsor booth is only applicable for sponsors in Ruby and Platinum plan as a paid add-on.",
        policy_help: "Please read the following policies and all agree to avide by. Note that the policy is required for all participants including attendees and booth staff.",
        ticket_help: "Select the tickets you'd like to include.",
        fallback_options: JSON.generate(Jsonnet.load(Rails.root.join("misc", "fallback_options_en.jsonnet"))),
      },
      {
        locale: "ja",
        head: "#{conference.name} への協賛をご検討いただきありがとうございます。<br>スポンサーシップを希望される企業様はスポンサー募集要項をご確認の上、下記のフォームにてお申し込みください。",
        plan_help: "各プランの詳細は 募集要項 をご参照ください。",
        booth_help: "Ruby, Platinum スポンサーはスポンサーブースを出展することができます。詳細は募集要項をご参照ください。",
        policy_help: "RubyKaigi ではスポンサー (ブーススタッフ) を含む全ての参加者に下記ポリシーへの同意を求めています。必要に応じてブース担当者や招待チケット利用者にもご共有ください。",
        ticket_help: "含めたいチケットを選択してください。",
        fallback_options: JSON.generate(Jsonnet.load(Rails.root.join("misc", "fallback_options_ja.jsonnet"))),
      }
    ].each do |form_desc_params|
      conference.form_descriptions.find_or_create_by!(form_desc_params)
    end

    # Organizations
    organizations = [
      { name: "ふつうのRubyの株式会社", domain: "ordinary-ruby.invalid", locale: "ja", plan: "Ruby", request: :customization },
      { name: "Great Ruby Inc.", domain: "great-ruby.invalid", locale: "en", plan: "Platinum", request: :billing, billing_contact: true },
      conference.name == 'RubyKaigi 2048' ? { name: "Amazing Ruby Inc.", domain: "amazing-ruby.invalid", locale: "en", plan: "Platinum", request: :note } : nil,
      { name: "合同会社ゆかいなRubyists", domain: "cheerfull-rubyists.invalid", locale: "ja", plan: "Gold", billing_contact: true },
      { name: "Little Rubyists LLC", domain: "little-rubyists.invalid", locale: "en", plan: "Silver", request: :note },
    ].compact

    puts "Creating organizations and sponsorships for #{conference.name}..."
    organizations.each do |org_params|
      organization = Organization.find_or_create_by!(name: org_params[:name]) do |org|
        org.domain = org_params[:domain]
      end

      # Sponsorships
      plans = conference.plans
      sponsorship_params = {
        id: sponsorship_id_next.call,
        name: organization.name,
        organization: organization,
        conference: conference,
        url: "https://#{organization.domain}",
        profile: "#{organization.name} is a leader in innovation and technology.",
        plan: plans.find_by(name: org_params[:plan]),
        booth_requested: (org_params[:plan] == "Ruby"),
        booth_assigned: false,
        locale: org_params[:locale],
        number_of_additional_attendees: 0,
      }
      sponsorship = Sponsorship.new(sponsorship_params)

      # Asset Files
      sponsorship.build_asset_file(
        prefix: "c-#{conference.id}/",
        extension: "zip",
      )

      # Contacts (:primary)
      sponsorship.build_contact(
        organization: sponsorship.name,
        name: Faker::Name.name,
        email: generate_contact_email.call(organization.domain),
        kind: :primary,
        address: Faker::Address.full_address,
        email_cc: "#{Faker::Internet.email(domain: organization.domain)}, #{Faker::Internet.email(domain: organization.domain)}"
      )

      # Contacts (:billing)
      if org_params[:billing_contact]
        sponsorship.contacts.build(
          organization: sponsorship.name,
          name: Faker::Name.name,
          email: Faker::Internet.email(domain: organization.domain),
          kind: :billing,
          address: Faker::Address.full_address
        )
      end

      # Sponsorship Requests
      if org_params[:request]
        body = if sponsorship.locale == "ja"
                 "#{sponsorship.name}のリクエストです。"
               else
                 "Hello from #{sponsorship.name}!"
               end
        request = SponsorshipRequest.new(kind: org_params[:request], body: )
        sponsorship.requests << request
      end

      sponsorship.accept if sponsorship.plan&.auto_acceptance || conference.name == 'RubyKaigi 2048'
      sponsorship.booth_assigned = sponsorship.booth_requested if conference.name == 'RubyKaigi 2048'
      sponsorship.save!
    end
  end
end

puts "Seeding complete!"
