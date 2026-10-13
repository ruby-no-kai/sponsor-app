# typed: strict
# frozen_string_literal: true

module Api
  module Sponsor
    # The registrations a sponsor's people make on Tito with the sponsorship's discount codes. Each
    # read asks Tito.
    class PassesController < Api::Sponsor::ApplicationController
      authorize :sponsorship
      #: () -> Rk::SponsorApp::SponsorServiceListPassRedemptionsResponse
      def list_pass_redemptions
        sponsorship = current_sponsorship
        conference = tito_conference
        unless TitoSource.exists?(sponsorship:, conference:)
          raise Errors::FailedPrecondition.new(detail: 'The sponsorship is not set up on the ticketing service yet.')
        end

        collection = PassRedemption.list_for_sponsorship(sponsorship)
        discount_codes = sponsorship.tito_discount_codes.sort_by { TitoDiscountCode.kinds.fetch(it.kind) }

        Rk::SponsorApp::SponsorServiceListPassRedemptionsResponse.new(
          conference: Api::ConferenceResource.new(conference).as_protobuf,
          discount_codes: discount_codes.map { Api::PassDiscountCodeResource.new(it).as_protobuf },
          registrations: collection.registrations.map { Api::PassRegistrationResource.new(it, params: {collection:}).as_protobuf },
          retraction_enabled: conference.pass_retraction_enabled?,
        )
      end

      # The sponsorship's conference, once it distributes tickets through Tito.
      #: () -> Conference
      private def tito_conference
        conference = Must.expect(current_sponsorship.conference)
        raise Errors::FailedPrecondition.new(detail: 'Tickets are not distributed yet.') unless conference.distributing_ticket?
        if conference.tito_slug.blank?
          raise Errors::FailedPrecondition.new(detail: 'Tickets are not distributed through the ticketing service.')
        end

        conference
      end
    end
  end
end
