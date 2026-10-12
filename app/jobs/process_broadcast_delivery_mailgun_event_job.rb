# typed: false
# frozen_string_literal: true

class ProcessBroadcastDeliveryMailgunEventJob < ApplicationJob
  def perform(event_data)
    @event_data = event_data
    delivery_id = user_variables['delivery_id']
    ApplicationRecord.transaction do
      delivery = BroadcastDelivery.lock.find(delivery_id)
      delivery.add_mailgun_event event_data

      # Events arrive out of order; only the latest one decides the status.
      if event_data['id'] == delivery.mailgun_events.last['id']
        delivery.status = case event_data['event']
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
      delivery.broadcast.update_status.save!
    end
  end

  attr_reader :event_data

  def user_variables
    event_data['user-variables'] || {}
  end
end
