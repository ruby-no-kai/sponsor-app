# typed: strict
# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'optparse'

class SlackWebhookJob < ApplicationJob
  # Queued jobs may still pass the {text:} Hash positionally.
  #: (?Hash[Symbol, String]?, ?text: String?, ?hook_name: Symbol | String) -> void
  def perform(legacy_payload = nil, text: nil, hook_name: :default)
    url = webhook_url(hook_name)
    return unless url

    text ||= Must.because(legacy_payload) { "producers pass text:" }.fetch(:text)
    Net::HTTP.post_form(
      URI.parse(url),
      payload: {text:}.to_json,
    )
  end

  #: (Symbol | String) -> String?
  private def webhook_url(hook_name)
    Rails.application.config.x.slack.webhook_urls&.dig(hook_name.to_sym)
  end
end
