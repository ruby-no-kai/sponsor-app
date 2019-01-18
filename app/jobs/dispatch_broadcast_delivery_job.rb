class DispatchBroadcastDeliveryJob < ApplicationJob
  def perform(delivery, force: false)
    Rails.logger.info "Delivering (#{delivery.id}): #{delivery.broadcast.description} (broadcast=#{delivery.broadcast.id}))"
    Raven.tags_context(delivery_id: delivery.id, broadcast_id: delivery.broadcast.id)
    ApplicationRecord.transaction do
      return if !force && !(delivery.created? || delivery.pending?)
      delivery.with_lock do
        return if !force && !(delivery.created? || delivery.pending?)
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
      Raven.capture_exception(e)
    end
  end
end
