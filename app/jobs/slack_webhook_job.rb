require 'net/http'
require 'uri'
require 'json'
require 'optparse'

class SlackWebhookJob < ApplicationJob
  def perform(payload, hook_name: :default)
    return unless webhook_url(hook_name)

    Net::HTTP.post_form(
      URI.parse(webhook_url(hook_name)),
      payload: payload.to_json,
    )
  end

  private

  def webhook_url(hook_name)
    Rails.application.config.x.slack.webhook_urls[hook_name.to_sym]
  end
end
