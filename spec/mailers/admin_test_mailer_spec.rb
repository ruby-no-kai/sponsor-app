# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AdminTestMailer, type: :mailer do
  subject(:mail) { described_class.with(to: 'staff@example.com').notify }

  def header_values(name)
    mail.header.fields.select { |f| f.name == name }.map(&:value)
  end

  it 'sends to the given address' do
    expect(mail.to).to eq(['staff@example.com'])
    expect(mail.subject).to eq("[#{Rails.application.config.x.org_name}] Notify")
  end

  it 'tags only the mailer and sets no List-ID' do
    expect(header_values('X-Mailgun-Tag')).to eq(['AdminTestMailer'])
    expect(JSON.parse(header_values('X-Mailgun-Variables').sole)).to eq('mailer' => 'AdminTestMailer')
    expect(header_values('List-ID')).to be_empty
  end

  it 'sends user variables without broadcast ids' do
    variables = Rk::SponsorApp::Internal::MailgunUserVariables.decode_json(header_values('X-Mailgun-Variables').sole)
    expect(variables.has_broadcast_id?).to be(false)
    expect(variables.has_delivery_id?).to be(false)
  end
end
