require 'net/http'
require 'uri'
require 'json'
require 'optparse'

class SlackWebhookJob < ApplicationJob
  def perform(payload)
    p payload
    return unless webhook_url

    p Net::HTTP.post_form(
      URI.parse(webhook_url),
      payload: payload.to_json,
    )
  end

  private

  def webhook_url
    Rails.application.config.x.slack.webhook_url
  end
end
