# typed: strict
# frozen_string_literal: true

module Api
  module Sponsor
    class BroadcastsController < Api::Sponsor::ApplicationController
      authorize :sponsorship
      #: () -> Rk::SponsorApp::SponsorServiceListBroadcastDeliveriesResponse
      def list_broadcast_deliveries
        sponsorship = current_sponsorship
        conference = Must.expect(sponsorship.conference)
        broadcasts = Broadcast
          .sent
          .where(hidden: false)
          .where(id: BroadcastDelivery.where(sponsorship:).select(:broadcast_id))
          .order(id: :desc)
        dashboard_url = user_conference_sponsorship_url(conference)

        Rk::SponsorApp::SponsorServiceListBroadcastDeliveriesResponse.new(
          conference: Api::ConferenceResource.new(conference).as_protobuf,
          broadcast_deliveries: broadcasts.map { Api::BroadcastDeliveryResource.new(it, params: {dashboard_url:}).as_protobuf },
        )
      end
    end
  end
end
