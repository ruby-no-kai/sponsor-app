# typed: strict
# frozen_string_literal: true

class ProcessBroadcastDeliveryMailgunEventJob < ApplicationJob
  # A Mailgun webhook event-data payload.
  #: type mailgun_event = Hash[String, untyped]

  # The webhook answers an unreadable event 406 instead of queueing it, and a job holding one would fail
  # every retry the same way.
  discard_on Google::Protobuf::ParseError do |_job, error|
    Sentry.capture_exception(error)
  end

  #: (mailgun_event) -> void
  def perform(event_data)
    event = Rk::SponsorApp::Internal::MailgunEvent.decode_json(JSON.generate(event_data), ignore_unknown_fields: true)
    ApplicationRecord.transaction do
      delivery = BroadcastDelivery.lock.find(event.user_variables&.delivery_id)
      delivery.add_mailgun_event event_data

      last_event = Must.because(delivery.mailgun_events.last) { "add_mailgun_event has just added an event" }
      # Events arrive out of order; only the latest one decides the status.
      if last_event['id'] == event.id
        delivery.status = case event.event
        when 'accepted'
          :accepted
        when 'rejected'
          :rejected
        when 'failed'
          :failed
        when 'delivered'
          :delivered
        when 'opened'
          :opened
        when 'clicked'
          :clicked
        else
          delivery.status
        end
      end

      delivery.save!
      Must.expect(delivery.broadcast).update_status.save!
    end
  end
end
