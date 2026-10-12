# frozen_string_literal: true

require 'openssl'

module Webhooks
  class MailgunController < ApplicationController
    skip_before_action :verify_authenticity_token

    def webhook
      return render(status: :unauthorized, plain: 'Signature Invalid') unless signature_valid?

      ApplicationRecord.transaction do
        # Mailgun does not retry on 406.
        unless MailgunWebhookToken.consume(token: signature_token, signed_at: signature_time)
          return render(status: :not_acceptable, plain: 'Token Reused')
        end

        case user_variables[:mailer]
        when 'BroadcastMailer'
          ProcessBroadcastDeliveryMailgunEventJob.perform_later(event_data)
        end
      end

      render status: :ok, plain: 'OK'
    end

    private def signature_valid?
      api_key = Rails.application.config.x.mailgun.api_key
      raise "no MAILGUN_API_KEY provided" unless api_key

      ts = params.dig(:signature, :timestamp)
      token = signature_token
      signature = params.dig(:signature, :signature)

      return false unless ts.is_a?(String) && token.is_a?(String) && signature.is_a?(String)
      return false unless ts.match?(/\A\d{1,12}\z/) && token.size <= 255
      return false unless MailgunWebhookToken.acceptable_time?(signature_time)

      data = [ts, token].join
      expected_signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('SHA256'), api_key, data)

      Rack::Utils.secure_compare signature, expected_signature
    end

    private def signature_token
      params.dig(:signature, :token)
    end

    private def signature_time
      Time.zone.at(params.dig(:signature, :timestamp).to_i)
    end

    private def event_data
      params.require('event-data').permit!
    end

    private def user_variables
      event_data['user-variables'] || {}
    end
  end
end
