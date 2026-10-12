# frozen_string_literal: true

require 'rails_helper'
require 'openssl'

RSpec.describe "Mailgun webhook", type: :request do
  let(:api_key) { 'key-dummy' }
  let(:token) { SecureRandom.hex(25) }
  let(:timestamp) { Time.zone.now.to_i.to_s }
  let(:event_data) { {'event' => 'delivered', 'id' => 'ev1', 'user-variables' => {'mailer' => 'BroadcastMailer', 'delivery_id' => '1'}} }

  around do |example|
    mailgun = Rails.application.config.x.mailgun
    original = mailgun.api_key
    mailgun.api_key = api_key
    example.run
  ensure
    mailgun.api_key = original
  end

  before do
    allow(ProcessBroadcastDeliveryMailgunEventJob).to receive(:perform_later)
  end

  def sign(timestamp, token)
    OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('SHA256'), api_key, [timestamp, token].join)
  end

  def post_webhook(timestamp:, token:, signature: sign(timestamp, token), data: event_data)
    post '/webhooks/mailgun', params: {signature: {timestamp:, token:, signature:}, 'event-data' => data}, as: :json
  end

  it "accepts a validly signed request" do
    post_webhook(timestamp:, token:)
    expect(response).to have_http_status(:ok)
    expect(ProcessBroadcastDeliveryMailgunEventJob).to have_received(:perform_later).once
  end

  it "rejects an invalid signature" do
    post_webhook(timestamp:, token:, signature: 'x' * 64)
    expect(response).to have_http_status(:unauthorized)
    expect(ProcessBroadcastDeliveryMailgunEventJob).not_to have_received(:perform_later)
  end

  it "rejects a stale timestamp" do
    post_webhook(timestamp: 2.hours.ago.to_i.to_s, token:)
    expect(response).to have_http_status(:unauthorized)
    expect(ProcessBroadcastDeliveryMailgunEventJob).not_to have_received(:perform_later)
  end

  it "rejects a far-future timestamp" do
    post_webhook(timestamp: 1.hour.from_now.to_i.to_s, token:)
    expect(response).to have_http_status(:unauthorized)
    expect(ProcessBroadcastDeliveryMailgunEventJob).not_to have_received(:perform_later)
  end

  it "accepts a timestamp slightly in the future" do
    post_webhook(timestamp: 30.seconds.from_now.to_i.to_s, token:)
    expect(response).to have_http_status(:ok)
    expect(ProcessBroadcastDeliveryMailgunEventJob).to have_received(:perform_later).once
  end

  it "rejects a replayed token with different event data" do
    post_webhook(timestamp:, token:)
    expect(response).to have_http_status(:ok)

    post_webhook(timestamp:, token:, data: event_data.merge('event' => 'failed', 'id' => 'ev2'))
    expect(response).to have_http_status(:not_acceptable)
    expect(ProcessBroadcastDeliveryMailgunEventJob).to have_received(:perform_later).once
  end

  it "rejects non-string signature fields" do
    post '/webhooks/mailgun', params: {signature: {timestamp: [timestamp], token:, signature: sign(timestamp, token)}, 'event-data' => event_data}, as: :json
    expect(response).to have_http_status(:unauthorized)
    expect(ProcessBroadcastDeliveryMailgunEventJob).not_to have_received(:perform_later)
  end
end
