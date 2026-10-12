# typed: true
# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'optparse'

class SlackWebhookJob < ApplicationJob
  def perform(payload, hook_name: :default)
    url = webhook_url(hook_name)
    return unless url

    Net::HTTP.post_form(
      URI.parse(url),
      payload: payload.to_json,
    )
  end

  private def webhook_url(hook_name)
    Rails.application.config.x.slack.webhook_urls&.dig(hook_name.to_sym)
  end
end
