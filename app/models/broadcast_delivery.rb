# frozen_string_literal: true

class BroadcastDelivery < ApplicationRecord
  belongs_to :broadcast
  belongs_to :sponsorship, optional: true

  validates :recipient, presence: true
  validates :status, presence: true

  enum :status, {created: 0, preparing: 1, ready: 2, pending: 3, sending: 4, sent: 5, failed: 6, rejected: 7, accepted: 8, delivered: 9, opened: 10, clicked: 11}

  def mailgun_events
    (self.meta ||= {})['mailgun_events'] ||= []
  end

  def add_mailgun_event(event)
    mailgun_events << event
    mailgun_events.sort_by! { |e| e['timestamp'] || 0 }
  end

  def recipient_ccs
    recipient_cc&.split(/[,;]\s*/) || []
  end
end
