# typed: strict
# frozen_string_literal: true

module Api
  module Admin
    class BroadcastsController < Api::Admin::ApplicationController
      include Api::Admin::BroadcastLookup
      include Api::Admin::BroadcastRecipientFilterArgument

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceListBroadcastsResponse
      def list_broadcasts
        broadcasts = conference.broadcasts.order(id: :desc)

        Rk::SponsorApp::AdminServiceListBroadcastsResponse.new(
          broadcasts: broadcasts.map { Api::AdminBroadcastSummaryResource.new(it).as_protobuf },
        )
      end

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceGetBroadcastResponse
      def get_broadcast
        broadcast = find_broadcast
        deliveries = broadcast.deliveries.includes(sponsorship: :conference).left_joins(:sponsorship)
          .order(Sponsorship.arel_table[:name].asc, recipient: :asc)

        Rk::SponsorApp::AdminServiceGetBroadcastResponse.new(
          broadcast: broadcast_message(broadcast),
          deliveries: deliveries.map { Api::AdminBroadcastDeliveryResource.new(it).as_protobuf },
        )
      end

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceCreateBroadcastResponse
      def create_broadcast
        filter = connect_request.recipient_filter #: Rk::SponsorApp::BroadcastRecipientFilter?
        recipient_filters = filter ? [recipient_filter_argument(filter)] : []
        broadcast = conference.broadcasts.build(staff: current_staff, status: :created)
        save_input!(broadcast)
        # Queued without a filter too, as the job is what makes the broadcast ready.
        CreateBroadcastDeliveriesJob.perform_later(broadcast, recipient_filters)

        Rk::SponsorApp::AdminServiceCreateBroadcastResponse.new(broadcast: broadcast_message(broadcast.reload))
      end

      # Saves under the row lock DispatchBroadcast takes, so the title and body cannot change while
      # the broadcast is being dispatched.
      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceUpdateBroadcastResponse
      def update_broadcast
        broadcast = find_broadcast
        broadcast.with_lock { save_input!(broadcast) }

        Rk::SponsorApp::AdminServiceUpdateBroadcastResponse.new(broadcast: broadcast_message(broadcast))
      end

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceDispatchBroadcastResponse
      def dispatch_broadcast
        broadcast = find_broadcast
        claim_dispatch!(broadcast)
        broadcast.perform_later!

        Rk::SponsorApp::AdminServiceDispatchBroadcastResponse.new(broadcast: broadcast_message(broadcast.reload))
      end

      # Takes the row lock that recipient changes also take, so a broadcast is dispatched once and
      # with the recipients it had when ready.
      #: (Broadcast) -> void
      private def claim_dispatch!(broadcast)
        broadcast.with_lock do
          unless broadcast.ready?
            raise Errors::FailedPrecondition.new(detail: "The broadcast #{broadcast.id} is #{broadcast.status}, not ready to dispatch.")
          end
          unless broadcast.deliveries.exists?
            raise Errors::FailedPrecondition.new(detail: "The broadcast #{broadcast.id} has no recipients.")
          end

          broadcast.update!(staff: current_staff, status: :pending)
        end
      end

      # A validation failure raises ActiveRecord::RecordInvalid, which is answered as
      # Errors::InvalidRecord on the input's fields.
      #: (Broadcast) -> void
      private def save_input!(broadcast)
        input = connect_request.input #: Rk::SponsorApp::BroadcastInput
        broadcast.update!(
          campaign: input.campaign,
          description: input.description,
          title: input.title,
          body: input.body,
        )
      rescue ActiveRecord::RecordNotUnique
        # Only a concurrent save gets past the campaign's uniqueness validation.
        raise Errors::Conflict.new(
          detail: "The conference #{conference.slug.inspect} already has a broadcast with the campaign #{broadcast.campaign.inspect}.",
        )
      end

      #: (Broadcast) -> Rk::SponsorApp::AdminBroadcast
      private def broadcast_message(broadcast)
        Api::AdminBroadcastResource.new(broadcast).as_protobuf
      end
    end
  end
end
