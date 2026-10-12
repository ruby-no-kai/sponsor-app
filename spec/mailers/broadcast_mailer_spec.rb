# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BroadcastMailer, type: :mailer do
  subject(:mail) { described_class.with(delivery:).announce }

  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:broadcast) { FactoryBot.create(:broadcast, conference:, title: 'Hello', body: 'Sign in: @LOGIN@') }

  def header_values(name)
    mail.header.fields.select { |f| f.name == name }.map(&:value)
  end

  context 'with a sponsorship' do
    let(:sponsorship) { FactoryBot.create(:sponsorship, conference:) }
    let(:delivery) { FactoryBot.create(:broadcast_delivery, broadcast:, sponsorship:, recipient: 'to@example.com', recipient_cc: 'cc@example.com') }

    it 'addresses the delivery recipients' do
      expect(mail.to).to eq(['to@example.com'])
      expect(mail.cc).to eq(['cc@example.com'])
      expect(mail.reply_to).to eq([conference.contact_email_address])
      expect(mail.subject).to eq("[#{conference.name}] Hello")
    end

    it 'tags the message for Mailgun' do
      expect(header_values('X-Mailgun-Tag')).to eq(['BroadcastMailer', "broadcast:#{broadcast.id}", "sponsorship:#{sponsorship.id}"])
      expect(JSON.parse(header_values('X-Mailgun-Variables').sole)).to eq(
        'mailer' => 'BroadcastMailer',
        'broadcast_id' => broadcast.id,
        'delivery_id' => delivery.id,
      )
    end

    it 'sets the List-ID from the list name and conference' do
      expect(header_values('List-ID')).to eq(["<broadcast.#{conference.slug}.#{Rails.application.config.x.default_email_host_part}>"])
    end

    it 'links a login token for the sponsorship contact' do
      body = mail.body.encoded
      token = SessionToken.find_by!(sponsorship:)
      expect(token.email).to eq(sponsorship.contact.email)
      expect(body).to include(token.handle)
    end
  end

  context 'without a sponsorship' do
    let(:delivery) { FactoryBot.create(:broadcast_delivery, broadcast:, recipient: 'raw@example.com') }

    it 'tags the message without a sponsorship' do
      expect(header_values('X-Mailgun-Tag')).to eq(['BroadcastMailer', "broadcast:#{broadcast.id}"])
    end

    it 'links the login form instead of a token' do
      expect { mail.body.encoded }.not_to change(SessionToken, :count)
    end
  end
end
