# typed: strict
# frozen_string_literal: true

module Api
  module Admin
    # Recipients change only while the broadcast is ready, under the broadcast's row lock, which
    # DispatchBroadcast also takes.
    class BroadcastDeliveriesController < Api::Admin::ApplicationController
      include Api::Admin::BroadcastLookup
      include Api::Admin::BroadcastRecipientFilterArgument

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceAddBroadcastRecipientsResponse
      def add_broadcast_recipients
        filter = connect_request.recipient_filter #: Rk::SponsorApp::BroadcastRecipientFilter?
        argument = recipient_filter_argument(Must.because(filter) { 'buf.validate requires the recipient filter' })
        broadcast = find_broadcast
        broadcast.with_lock do
          require_ready!(broadcast)
          broadcast.update!(status: :modifying)
          CreateBroadcastDeliveriesJob.perform_later(broadcast, [argument])
        end

        Rk::SponsorApp::AdminServiceAddBroadcastRecipientsResponse.new(
          broadcast: Api::AdminBroadcastResource.new(broadcast.reload).as_protobuf,
        )
      end

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceRemoveBroadcastDeliveryResponse
      def remove_broadcast_delivery
        broadcast = find_broadcast
        delivery = find_delivery(broadcast)
        broadcast.with_lock do
          require_ready!(broadcast)
          unless delivery.reload.ready?
            raise Errors::FailedPrecondition.new(detail: "The delivery #{delivery.id} is #{delivery.status}, past removal.")
          end

          delivery.destroy!
        end

        Rk::SponsorApp::AdminServiceRemoveBroadcastDeliveryResponse.new
      end

      #: (Broadcast) -> BroadcastDelivery
      private def find_delivery(broadcast)
        id = connect_request.delivery_id #: Integer
        broadcast.deliveries.find_by(id:) || raise(Errors::NotFound.new(
          detail: "The broadcast #{broadcast.id} has no delivery #{id}.",
        ))
      end

      #: (Broadcast) -> void
      private def require_ready!(broadcast)
        return if broadcast.ready?

        raise Errors::FailedPrecondition.new(detail: "The broadcast #{broadcast.id} is #{broadcast.status}, not ready.")
      end
    end
  end
end
