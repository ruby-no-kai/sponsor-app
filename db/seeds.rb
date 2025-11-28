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
  # Create admin staff for broadcasts
  puts "Creating staff..."
  staff = Staff.find_or_create_by!(login: "admin") do |s|
    s.name = "Admin User"
    s.uid = "12345"
  end

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
    conference.update!(conf_params.except(:id))

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
      conference.plans.find_or_create_by!(name: plan_params.fetch(:name)).update!(plan_params)
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
      conference.form_descriptions.find_or_create_by!(locale: form_desc_params.fetch(:locale)).update!(form_desc_params)
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
      sponsorship = Sponsorship.find_or_initialize_by(
        conference: conference,
        name: organization.name
      )

      # Assign ID only for new records
      sponsorship.id ||= sponsorship_id_next.call

      # Update attributes
      sponsorship.organization = organization
      sponsorship.url = "https://#{organization.domain}"
      sponsorship.profile = "#{organization.name} is a leader in innovation and technology."
      sponsorship.plan = plans.find_by(name: org_params[:plan])
      sponsorship.booth_requested = (org_params[:plan] == "Ruby")
      sponsorship.locale = org_params[:locale]
      sponsorship.number_of_additional_attendees = 0

      sponsorship.booth_assigned = sponsorship.booth_requested && conference.name == 'RubyKaigi 2048'
      sponsorship.accept if conference.name == 'RubyKaigi 2048'

      # Asset Files (update or build)
      if sponsorship.asset_file
        sponsorship.asset_file.assign_attributes(
          prefix: "c-#{conference.id}/",
          extension: "zip"
        )
      else
        sponsorship.build_asset_file(
          prefix: "c-#{conference.id}/",
          extension: "zip"
        )
      end

      # Clear and rebuild contacts to ensure clean state
      sponsorship.contacts.destroy_all

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
        sponsorship.build_alternate_billing_contact(
          organization: sponsorship.name,
          name: Faker::Name.name,
          email: Faker::Internet.email(domain: organization.domain),
          kind: :billing,
          address: Faker::Address.full_address
        )
      end

      # Clear and rebuild requests to ensure clean state
      sponsorship.requests.destroy_all

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

    # Broadcasts and Deliveries
    puts "Creating broadcasts and deliveries for #{conference.name}..."

    # Broadcast 1: Welcome Email (sent)
    broadcast1 = Broadcast.find_or_create_by!(
      conference: conference,
      campaign: "welcome-#{conference.id}"
    ) do |b|
      b.staff = staff
      b.status = :sent
      b.title = "Welcome to #{conference.name}!"
      b.description = "Welcome email sent to all sponsors"
      b.body = <<~MARKDOWN
        # Welcome to #{conference.name}!

        Thank you for sponsoring #{conference.name}. We're excited to have you on board!

        ## Next Steps

        Please visit your sponsor portal to complete your profile and submit your logo:

        @LOGIN@

        If you have any questions, please don't hesitate to reach out.

        Best regards,
        The #{conference.name} Team
      MARKDOWN
      b.dispatched_at = Time.zone.now - 2.weeks
      b.hidden = false
    end

    # Create deliveries for all sponsorships (delivered status)
    conference.sponsorships.includes(:contact).each do |sponsorship|
      BroadcastDelivery.find_or_create_by!(
        broadcast: broadcast1,
        sponsorship: sponsorship
      ) do |d|
        d.recipient = sponsorship.contact.email
        d.recipient_cc = sponsorship.contact.email_cc
        d.status = :delivered
        d.dispatched_at = broadcast1.dispatched_at
      end
    end

    # Broadcast 2: Booth Information (sent, only to booth sponsors)
    broadcast2 = Broadcast.find_or_create_by!(
      conference: conference,
      campaign: "booth-info-#{conference.id}"
    ) do |b|
      b.staff = staff
      b.status = :sent
      b.title = "Booth Setup Information"
      b.description = "Booth setup instructions for exhibitors"
      b.body = <<~MARKDOWN
        # Booth Setup Information

        Thank you for participating as an exhibitor at #{conference.name}!

        ## Important Information

        - Setup time: Day before the conference, 3:00 PM - 6:00 PM
        - Booth dimensions: 2m x 2m
        - Power outlet: 1 available per booth

        ## Submit Your Booth Plan

        Please submit your booth plan and requirements through the sponsor portal:

        @FORM@

        We look forward to seeing your booth!

        Best regards,
        The #{conference.name} Team
      MARKDOWN
      b.dispatched_at = Time.zone.now - 1.week
      b.hidden = false
    end

    # Create deliveries only for sponsorships with booths (sent/opened status)
    booth_sponsorships = conference.sponsorships.includes(:contact).where(booth_assigned: true)
    booth_sponsorships.each_with_index do |sponsorship, idx|
      BroadcastDelivery.find_or_create_by!(
        broadcast: broadcast2,
        sponsorship: sponsorship
      ) do |d|
        d.recipient = sponsorship.contact.email
        d.recipient_cc = sponsorship.contact.email_cc
        d.status = idx.even? ? :sent : :opened
        d.dispatched_at = broadcast2.dispatched_at
        d.opened_at = idx.odd? ? (broadcast2.dispatched_at + 1.day) : nil
      end
    end

    # Broadcast 3: Important Update (ready, not sent yet)
    broadcast3 = Broadcast.find_or_create_by!(
      conference: conference,
      campaign: "update-#{conference.id}"
    ) do |b|
      b.staff = staff
      b.status = :ready
      b.title = "Important Update - Please Review"
      b.description = "Important update for all sponsors (not sent yet)"
      b.body = <<~MARKDOWN
        # Important Update

        Dear Sponsors,

        We have an important update regarding #{conference.name}.

        ## Schedule Changes

        Please note the following schedule adjustments:
        - Registration opens 30 minutes earlier
        - Keynote time has been adjusted

        ## Action Required

        Please review the updated schedule in your portal and confirm your attendance.

        Thank you for your cooperation!

        Best regards,
        The #{conference.name} Team
      MARKDOWN
      b.dispatched_at = nil
      b.hidden = false
    end

    # Create deliveries for all sponsorships (ready status, not sent)
    conference.sponsorships.includes(:contact).each do |sponsorship|
      BroadcastDelivery.find_or_create_by!(
        broadcast: broadcast3,
        sponsorship: sponsorship
      ) do |d|
        d.recipient = sponsorship.contact.email
        d.recipient_cc = sponsorship.contact.email_cc
        d.status = :ready
        d.dispatched_at = nil
      end
    end

    # Broadcast 4: Thank you Email (sent)
    broadcast4 = Broadcast.find_or_create_by!(
      conference: conference,
      campaign: "thankyou-#{conference.id}"
    ) do |b|
      b.staff = staff
      b.status = :sent
      b.title = "Thank you from #{conference.name}"
      b.description = "Appreciation"
      b.body = <<~MARKDOWN
        # Welcome to #{conference.name}!

        Thank you for sponsoring #{conference.name}. We're excited to have you on board!

        Best regards,
        The #{conference.name} Team
      MARKDOWN
      b.dispatched_at = Time.zone.now - 2.weeks
      b.hidden = false
    end

    # Create deliveries for all sponsorships (delivered status)
    conference.sponsorships.includes(:contact).each do |sponsorship|
      BroadcastDelivery.find_or_create_by!(
        broadcast: broadcast4,
        sponsorship: sponsorship
      ) do |d|
        d.recipient = sponsorship.contact.email
        d.recipient_cc = sponsorship.contact.email_cc
        d.status = :delivered
        d.dispatched_at = broadcast4.dispatched_at
      end
    end

    # Announcements
    puts "Creating announcements for #{conference.name}..."

    # Announcement 1: Welcome (published, pinned)
    Announcement.find_or_create_by!(
      conference: conference,
      issue: "welcome",
      locale: "en"
    ) do |a|
      a.staff = staff
      a.title = "Welcome Sponsors!"
      a.body = <<~MARKDOWN
        # Welcome to #{conference.name}

        Thank you for your sponsorship! We're excited to have you as part of #{conference.name}.

        Please check this page regularly for important updates and announcements.
      MARKDOWN
      a.published_at = Time.zone.now - 2.weeks
      a.stickiness = 1
      a.exhibitors_only = false
    end

    Announcement.find_or_create_by!(
      conference: conference,
      issue: "welcome",
      locale: "ja"
    ) do |a|
      a.staff = staff
      a.title = "スポンサーの皆様へ"
      a.body = <<~MARKDOWN
        # #{conference.name} へようこそ

        この度はご協賛いただきありがとうございます！#{conference.name} の一員として、皆様をお迎えできることを嬉しく思います。

        重要な更新やお知らせについては、このページを定期的にご確認ください。
      MARKDOWN
      a.published_at = Time.zone.now - 2.weeks
      a.stickiness = 1
      a.exhibitors_only = false
    end

    # Announcement 2: Important Information (published)
    Announcement.find_or_create_by!(
      conference: conference,
      issue: "important-info",
      locale: "en"
    ) do |a|
      a.staff = staff
      a.title = "Important: Asset Submission Deadline"
      a.body = <<~MARKDOWN
        ## Asset Submission Reminder

        Please remember to submit your logo and company information by the deadline.

        If you have any questions, please contact us at #{conference.contact_email_address}.
      MARKDOWN
      a.published_at = Time.zone.now - 1.week
      a.stickiness = 0
      a.exhibitors_only = false
    end

    Announcement.find_or_create_by!(
      conference: conference,
      issue: "important-info",
      locale: "ja"
    ) do |a|
      a.staff = staff
      a.title = "重要: 素材提出期限について"
      a.body = <<~MARKDOWN
        ## 素材提出のお願い

        期限までにロゴや企業情報をご提出いただきますようお願いいたします。

        ご不明な点がございましたら、#{conference.contact_email_address} までお問い合わせください。
      MARKDOWN
      a.published_at = Time.zone.now - 1.week
      a.stickiness = 0
      a.exhibitors_only = false
    end

    # Announcement 3: Upcoming Event (unpublished draft)
    Announcement.find_or_create_by!(
      conference: conference,
      issue: "upcoming-event",
      locale: "en"
    ) do |a|
      a.staff = staff
      a.title = "[DRAFT] Pre-Conference Meetup"
      a.body = <<~MARKDOWN
        ## Pre-Conference Sponsor Meetup

        We're planning a pre-conference meetup for sponsors. Details coming soon!

        - Date: TBA
        - Time: TBA
        - Location: TBA
      MARKDOWN
      a.published_at = nil
      a.stickiness = 0
      a.exhibitors_only = false
    end

    Announcement.find_or_create_by!(
      conference: conference,
      issue: "upcoming-event",
      locale: "ja"
    ) do |a|
      a.staff = staff
      a.title = "[下書き] カンファレンス前のミートアップ"
      a.body = <<~MARKDOWN
        ## スポンサー向けプレカンファレンスミートアップ

        スポンサーの皆様向けのプレカンファレンスミートアップを企画中です。詳細は追ってお知らせします！

        - 日時: 未定
        - 時間: 未定
        - 場所: 未定
      MARKDOWN
      a.published_at = nil
      a.stickiness = 0
      a.exhibitors_only = false
    end
  end
end


ApplicationRecord.connection.execute("alter sequence sponsorships_id_seq restart with #{Sponsorship.maximum(:id).to_i + 1}")

puts "Seeding complete!"
