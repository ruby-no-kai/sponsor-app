# frozen_string_literal: true

require 'openssl'

module Webhooks
  class MailgunController < ApplicationController
    skip_before_action :verify_authenticity_token

    def webhook
      return render(status: :unauthorized, plain: 'Signature Invalid') unless signature_valid?

      case user_variables[:mailer]
      when 'BroadcastMailer'
        ProcessBroadcastDeliveryMailgunEventJob.perform_later(event_data)
      end

      render status: :ok, plain: 'OK'
    end

    private def signature_valid?
      api_key = Rails.application.config.x.mailgun.api_key
      raise "no MAILGUN_API_KEY provided" unless api_key

      ts = params.dig(:signature, :timestamp)
      token = params.dig(:signature, :token)
      signature = params.dig(:signature, :signature)

      return false unless ts && token && signature
      return false if (Time.zone.now - Time.zone.at(ts.to_i)) > 3600

      data = [ts, token].join
      expected_signature = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('SHA256'), api_key, data)

      Rack::Utils.secure_compare signature, expected_signature
    end

    private def event_data
      params.require('event-data').permit!
    end

    private def user_variables
      event_data['user-variables'] || {}
    end
  end
end
