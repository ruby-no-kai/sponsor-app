# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SessionTokenMailer, type: :mailer do
  subject(:mail) { described_class.with(token:).notify }

  let(:host_part) { Rails.application.config.x.default_email_host_part }

  def header_values(name)
    mail.header.fields.select { |f| f.name == name }.map(&:value)
  end

  context 'with a sponsorship' do
    let(:sponsorship) { FactoryBot.create(:sponsorship, conference: FactoryBot.create(:conference, :full)) }
    let(:token) { FactoryBot.create(:session_token, sponsorship:) }

    it 'sends the login link to the token email' do
      expect(mail.to).to eq([token.email])
      expect(mail.subject).to eq("[#{Rails.application.config.x.org_name}] Your login link for our sponsor's portal")
      expect(mail.body.encoded).to include(token.handle)
    end

    it 'tags the sponsorship and lists under its conference' do
      expect(header_values('X-Mailgun-Tag')).to eq(['SessionTokenMailer', "sponsorship:#{sponsorship.id}"])
      expect(header_values('List-ID')).to eq(["<login.#{sponsorship.conference.slug}.#{host_part}>"])
    end
  end

  context 'without a sponsorship' do
    let(:token) { FactoryBot.create(:session_token) }

    it 'tags only the mailer and lists without a conference' do
      expect(header_values('X-Mailgun-Tag')).to eq(['SessionTokenMailer'])
      expect(header_values('List-ID')).to eq(["<login.#{host_part}>"])
    end
  end
end
