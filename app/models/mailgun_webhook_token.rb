# frozen_string_literal: true

# Mailgun webhook signature token already accepted, kept to reject replays.
class MailgunWebhookToken < ApplicationRecord
  MAX_AGE = 1.hour
  MAX_FUTURE_SKEW = 5.minutes

  validates :token, presence: true
  validates :signed_at, presence: true

  def self.acceptable_time?(signed_at, now: Time.zone.now)
    signed_at.between?(now - MAX_AGE, now + MAX_FUTURE_SKEW)
  end

  # Returns false when the token has been consumed before.
  def self.consume(token:, signed_at:, now: Time.zone.now)
    where(signed_at: ...(now - MAX_AGE)).delete_all
    insert({token:, signed_at:}, unique_by: :token, returning: [:id]).rows.any? # rubocop:disable Rails/SkipsModelValidations
  end
end
