# typed: strict
# frozen_string_literal: true

module Api
  module Admin
    class BroadcastsController < Api::Admin::ApplicationController
      include Api::Admin::BroadcastLookup

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
        broadcast = conference.broadcasts.build(staff: current_staff, status: :created)
        save_input!(broadcast)
        # Queued with no recipients to collect, as the job is what makes the broadcast ready.
        CreateBroadcastDeliveriesJob.perform_later(broadcast, [])

        Rk::SponsorApp::AdminServiceCreateBroadcastResponse.new(broadcast: broadcast_message(broadcast.reload))
      end

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceUpdateBroadcastResponse
      def update_broadcast
        broadcast = find_broadcast
        save_input!(broadcast)

        Rk::SponsorApp::AdminServiceUpdateBroadcastResponse.new(broadcast: broadcast_message(broadcast))
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
