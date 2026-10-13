# typed: strict
# frozen_string_literal: true

module Api
  module Sponsor
    # The registrations a sponsor's people make on Tito with the sponsorship's discount codes. Each
    # read asks Tito, except for a retraction already saved.
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

      authorize :sponsorship
      #: () -> Rk::SponsorApp::SponsorServiceGetPassRetractionResponse
      def get_pass_retraction
        conference = tito_conference

        Rk::SponsorApp::SponsorServiceGetPassRetractionResponse.new(
          conference: Api::ConferenceResource.new(conference).as_protobuf,
          retraction: Api::PassRetractionResource.new(saved_or_prepared_retraction).as_protobuf,
          retraction_enabled: conference.pass_retraction_enabled?,
        )
      end

      # Runs the cancellation on Tito before answering. When Tito fails, the saved retraction stays
      # uncompleted, and calling again runs it again.
      authorize :sponsorship
      #: () -> Rk::SponsorApp::SponsorServiceCreatePassRetractionResponse
      def create_pass_retraction
        unless tito_conference.pass_retraction_enabled?
          raise Errors::FailedPrecondition.new(detail: 'Voiding registrations has closed. Contact the organizers instead.')
        end

        input = connect_request.input #: Rk::SponsorApp::PassRetractionInput
        retraction = saved_or_prepared_retraction
        unless retraction.completed?
          retraction.reason = input.reason
          retraction.save!
          RetractTitoTicketJob.perform_now(retraction)
        end

        Rk::SponsorApp::SponsorServiceCreatePassRetractionResponse.new(
          retraction: Api::PassRetractionResource.new(retraction).as_protobuf,
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

      # The sponsorship's saved retraction of the registration, else one prepared from the
      # registration Tito holds now. A registration that did not come through the sponsorship is
      # answered as not found, as one Tito lacks is, so its details stay with its own sponsor.
      #: () -> TitoTicketRetraction
      private def saved_or_prepared_retraction
        sponsorship = current_sponsorship
        registration_id = connect_request.tito_registration_id #: String
        saved = TitoTicketRetraction.find_by(sponsorship:, tito_registration_id: registration_id)
        return saved if saved

        prepared = TitoTicketRetraction.prepare(sponsorship, registration_id)
        raise registration_not_found unless prepared.registered_through_sponsorship?

        prepared
      rescue HTTPX::HTTPError => e
        raise unless e.status == 404

        raise registration_not_found
      end

      #: () -> Errors::NotFound
      private def registration_not_found
        Errors::NotFound.new(detail: 'No registration made with your discount codes has this ID.')
      end
    end
  end
end
