# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::ConferenceResource do
  let(:conference) do
    FactoryBot.build(
      :conference,
      slug: 'rubykaigi2048',
      application_opens_at: Time.zone.parse('2026-01-15T10:00:00.5Z'),
      booth_capacity: 0,
    )
  end

  it 'builds the bound message' do
    expect(described_class.new(conference).as_protobuf).to eq(Rk::SponsorApp::Conference.new(
      slug: 'rubykaigi2048',
      name: conference.name,
      contact_email_address: conference.contact_email_address,
      application_opens_at: Google::Protobuf::Timestamp.new(seconds: Time.utc(2026, 1, 15, 10).to_i, nanos: 500_000_000),
      no_plan_allowed: true,
      booths_offered: false,
    ))
  end

  it 'publishes times in RFC 3339 and leaves unset ones out' do
    json = JSON.parse(described_class.new(conference).to_json)

    expect(json).to include('application_opens_at' => '2026-01-15T10:00:00.500Z')
    expect(json).not_to have_key('application_closes_at')
  end

  it 'refuses at load time to drift from the message' do
    expect do
      Class.new(Api::ApplicationResource) do
        with_protobuf(Rk::SponsorApp::Conference) { attributes :slug, :name }
      end
    end.to raise_error(Protobufable::Error, /is missing/)
  end
end
