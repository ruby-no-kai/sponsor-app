# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SponsorshipWelcomeMailer, type: :mailer do
  let(:conference) { FactoryBot.create(:conference) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:) }

  def mailgun_tags(mail)
    mail.header.fields.select { |f| f.name == 'X-Mailgun-Tag' }.map(&:value)
  end

  describe '#admin_email' do
    it 'tags the sponsorship with the admin prefix' do
      mail = described_class.with(sponsorship:).admin_email
      expect(mailgun_tags(mail)).to include("admin/sponsorship:#{sponsorship.id}")
    end
  end

  describe '#user_email' do
    let(:session_token) { FactoryBot.create(:session_token, sponsorship:, email: sponsorship.contact.email) }

    it 'tags the sponsorship without the admin prefix' do
      mail = described_class.with(sponsorship:, session_token:).user_email
      expect(mailgun_tags(mail)).to include("sponsorship:#{sponsorship.id}")
      expect(mailgun_tags(mail)).not_to include("admin/sponsorship:#{sponsorship.id}")
    end
  end
end
