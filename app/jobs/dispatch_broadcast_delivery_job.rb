class DispatchBroadcastDeliveryJob < ApplicationJob
  def perform(delivery, force: false)
    Rails.logger.info "Delivering (#{delivery.id}): #{delivery.broadcast.description} (broadcast=#{delivery.broadcast.id}))"
    Sentry.with_scope do |scope|
      scope.set_tags(delivery_id: delivery.id, broadcast_id: delivery.broadcast.id)
      perform_real(delivery, force: force)
    end
  end

  def perform_real(delivery, force: false)
    ApplicationRecord.transaction do
      if !force && !(delivery.created? || delivery.pending?)
        Rails.logger.info  "Delivering (#{delivery.id}): skip (force=#{force}, created?=#{delivery.created?}, pending?=#{delivery.pending?})"
        return
      end
      delivery.with_lock do
        if !force && !(delivery.created? || delivery.pending?)
          Rails.logger.info  "Delivering (#{delivery.id}): skip (force=#{force}, created?=#{delivery.created?}, pending?=#{delivery.pending?})"
          return
        end
        delivery.update!(status: :sending)

        Rails.logger.info "Delivering (#{delivery.id}): sending email"

        begin
          BroadcastMailer.with(delivery: delivery).announce.deliver_now
        rescue => e
          delivery.update!(status: :failed)
          Rails.logger.error "Delivering (#{delivery.id}): failed with exception"
          raise e
        else
          delivery.update!(status: :sent)
          Rails.logger.info "Delivering (#{delivery.id}): sent"
        end
      end
    end
  ensure
    begin
      p delivery.broadcast.deliveries.distinct.order(status: :asc).pluck(:status)
      delivery.broadcast.update_status.save!
    rescue => e
      raise if Rails.env.development?
      Sentry.capture_exception(e)
    end
  end
end
