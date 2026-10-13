# frozen_string_literal: true

require 'rails_helper'
require 'openssl'

RSpec.describe "Mailgun webhook", type: :request do
  let(:api_key) { 'mailgun-api-key' }
  let(:broadcast) { FactoryBot.create(:broadcast, status: :sending) }
  let(:delivery) { FactoryBot.create(:broadcast_delivery, broadcast:, status: :sent) }
  let(:event_data) { {'id' => 'a', 'event' => 'delivered', 'timestamp' => 100.5, 'user-variables' => user_variables} }

  before do
    allow(Rails.application.config.x.mailgun).to receive(:api_key).and_return(api_key)
  end

  def signature(key: api_key)
    timestamp = Time.zone.now.to_i.to_s
    token = 'mailgun-token'
    {timestamp:, token:, signature: OpenSSL::HMAC.hexdigest('SHA256', key, "#{timestamp}#{token}")}
  end

  def post_webhook(signature: self.signature)
    post '/webhooks/mailgun', params: {signature:, 'event-data' => event_data}, as: :json
  end

  context "with user variables from an email sent with numeric ids" do
    let(:user_variables) { {'mailer' => 'BroadcastMailer', 'broadcast_id' => broadcast.id, 'delivery_id' => delivery.id} }

    it "records the event on the delivery" do
      post_webhook

      expect(response).to have_http_status(:ok)
      delivery.reload
      expect(delivery.status).to eq('delivered')
      expect(delivery.mailgun_events).to eq([event_data])
    end
  end

  context "with user variables from an email sent with string ids" do
    let(:user_variables) { {'mailer' => 'BroadcastMailer', 'broadcast_id' => broadcast.id.to_s, 'delivery_id' => delivery.id.to_s} }

    it "records the event on the delivery" do
      post_webhook

      expect(response).to have_http_status(:ok)
      delivery.reload
      expect(delivery.status).to eq('delivered')
      expect(delivery.mailgun_events).to eq([event_data])
    end
  end

  context "with fields this app does not read" do
    let(:user_variables) { {'mailer' => 'BroadcastMailer', 'broadcast_id' => broadcast.id, 'delivery_id' => delivery.id, 'campaign' => 'x'} }
    let(:event_data) do
      {
        'id' => 'a',
        'event' => 'delivered',
        'timestamp' => 100.5,
        'recipient' => 'alice@example.invalid',
        'delivery-status' => {'code' => 250, 'message' => 'OK'},
        'user-variables' => user_variables,
      }
    end

    it "records the event as Mailgun sent it" do
      post_webhook

      expect(response).to have_http_status(:ok)
      delivery.reload
      expect(delivery.status).to eq('delivered')
      expect(delivery.mailgun_events).to eq([event_data])
    end
  end

  context "with a field of another type than this app reads" do
    let(:user_variables) { {'mailer' => 'BroadcastMailer', 'broadcast_id' => broadcast.id, 'delivery_id' => delivery.id} }
    let(:event_data) { {'id' => 12345, 'event' => 'delivered', 'timestamp' => 100.5, 'user-variables' => user_variables} }

    before do
      allow(ProcessBroadcastDeliveryMailgunEventJob).to receive(:perform_later)
      allow(Sentry).to receive(:capture_exception)
    end

    it "answers 406, which Mailgun does not retry, and reports the event" do
      post_webhook

      expect(response).to have_http_status(:not_acceptable)
      expect(ProcessBroadcastDeliveryMailgunEventJob).not_to have_received(:perform_later)
      expect(Sentry).to have_received(:capture_exception).with(instance_of(Google::Protobuf::ParseError))
    end
  end

  context "without user variables" do
    let(:event_data) { {'id' => 'a', 'event' => 'delivered', 'timestamp' => 100.5} }

    before { allow(ProcessBroadcastDeliveryMailgunEventJob).to receive(:perform_later) }

    it "accepts the event without processing it" do
      post_webhook

      expect(response).to have_http_status(:ok)
      expect(ProcessBroadcastDeliveryMailgunEventJob).not_to have_received(:perform_later)
    end
  end

  context "with user variables from another mailer" do
    let(:user_variables) { {'mailer' => 'SessionTokenMailer'} }

    before { allow(ProcessBroadcastDeliveryMailgunEventJob).to receive(:perform_later) }

    it "accepts the event without processing it" do
      post_webhook

      expect(response).to have_http_status(:ok)
      expect(ProcessBroadcastDeliveryMailgunEventJob).not_to have_received(:perform_later)
    end
  end

  context "with an invalid signature" do
    let(:user_variables) { {'mailer' => 'BroadcastMailer', 'broadcast_id' => broadcast.id, 'delivery_id' => delivery.id} }

    it "refuses the event" do
      post_webhook(signature: signature(key: 'another-key'))

      expect(response).to have_http_status(:unauthorized)
      expect(delivery.reload.mailgun_events).to be_empty
    end
  end
end
