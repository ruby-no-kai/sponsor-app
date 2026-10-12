# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SponsorshipWelcomeMailer, type: :mailer do
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:) }
  let(:contact) { sponsorship.contact }
  let(:host_part) { Rails.application.config.x.default_email_host_part }

  def header_values(mail, name)
    mail.header.fields.select { |f| f.name == name }.map(&:value)
  end

  describe '#user_email' do
    subject(:mail) { described_class.with(sponsorship:, session_token:).user_email }

    let(:session_token) { FactoryBot.create(:session_token, email: contact.email) }

    before do
      contact.update!(email_cc: 'cc@example.com')
    end

    it 'welcomes the primary contact' do
      expect(mail.to).to eq([contact.email])
      expect(mail.cc).to eq(['cc@example.com'])
      expect(mail.reply_to).to eq([conference.contact_email_address])
      expect(mail.subject).to eq("[#{conference.name}] Thank you for sponsoring us")
      expect(mail.body.encoded).to include(session_token.handle)
    end

    it 'tags the sponsorship and lists under its conference' do
      expect(header_values(mail, 'X-Mailgun-Tag')).to eq(['SponsorshipWelcomeMailer', "sponsorship:#{sponsorship.id}"])
      expect(header_values(mail, 'List-ID')).to eq(["<welcome.#{conference.slug}.#{host_part}>"])
    end
  end

  describe '#admin_email' do
    subject(:mail) { described_class.with(sponsorship:).admin_email }

    it 'notifies the conference contact' do
      expect(mail.to).to eq([conference.contact_email_address])
      expect(mail.reply_to).to eq([contact.email])
      expect(mail.subject).to eq("[#{conference.name}] New: #{contact.organization}")
      expect(mail.body.encoded).to include(sponsorship.name)
    end

    it 'tags the sponsorship and lists under its conference' do
      expect(header_values(mail, 'X-Mailgun-Tag')).to eq(['SponsorshipWelcomeMailer', "admin/sponsorship:#{sponsorship.id}"])
      expect(header_values(mail, 'List-ID')).to eq(["<#{conference.slug}.#{host_part}>"])
    end
  end
end
