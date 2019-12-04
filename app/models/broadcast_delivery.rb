class BroadcastDelivery < ApplicationRecord
  belongs_to :broadcast
  belongs_to :sponsorship, optional: true

  validates :recipient, presence: true
  validates :status, presence: true

  enum status: %i(created preparing ready pending sending sent failed rejected accepted delivered opened clicked)

  def mailgun_events
    (self.meta ||= {})['mailgun_events'] ||= []
  end

  def add_mailgun_event(event)
    mailgun_events << event
    mailgun_events.sort_by!{ |_| _['timestamp'] || 0 }
  end

  def recipient_ccs
    recipient_cc&.split(/[,;]\s*/) || []
  end
end
