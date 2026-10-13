# typed: strict
# frozen_string_literal: true

module Api
  module Sponsor
    # Events a sponsor hosts. Event IDs resolve within the signed-in sponsorship only.
    class SponsorEventsController < Api::Sponsor::ApplicationController
      include Api::Sponsor::SponsorEventGates

      authorize :sponsorship
      #: () -> Rk::SponsorApp::SponsorServiceGetSponsorEventFormResponse
      def get_sponsor_event_form
        require_accepted_sponsorship!
        conference = event_conference
        description = conference.form_description_for_locale_maybe

        Rk::SponsorApp::SponsorServiceGetSponsorEventFormResponse.new(
          conference: Api::ConferenceResource.new(conference).as_protobuf,
          submission_open: !!conference.event_submission_open?,
          sponsor_event_help_html: description&.sponsor_event_help_html.to_s,
          event_policy_html: description&.event_policy_html.to_s,
        )
      end

      authorize :sponsorship
      #: () -> Rk::SponsorApp::SponsorServiceGetSponsorEventResponse
      def get_sponsor_event
        require_accepted_sponsorship!
        event = find_sponsor_event

        Rk::SponsorApp::SponsorServiceGetSponsorEventResponse.new(
          conference: Api::ConferenceResource.new(event_conference).as_protobuf,
          sponsor_event: sponsor_event_message(event),
        )
      end

      authorize :sponsorship
      #: () -> Rk::SponsorApp::SponsorServiceCreateSponsorEventResponse
      def create_sponsor_event
        input = connect_request.input #: Rk::SponsorApp::SponsorEventInput
        require_event_submission_open!

        event = current_sponsorship.sponsor_events.build
        assign_input(event, input)
        event.policy_acknowledged_at = Time.zone.now
        event.asset_file = find_unattached_asset_file(input.asset_file_id) if input.has_asset_file_id?
        event.save!
        ProcessSponsorEventEditJob.perform_later(Must.expect(event.last_editing_history))

        Rk::SponsorApp::SponsorServiceCreateSponsorEventResponse.new(sponsor_event: sponsor_event_message(event))
      end

      authorize :sponsorship
      #: () -> Rk::SponsorApp::SponsorServiceUpdateSponsorEventResponse
      def update_sponsor_event
        input = connect_request.input #: Rk::SponsorApp::SponsorEventInput
        require_event_submission_open!
        event = find_editable_sponsor_event

        ActiveRecord::Base.transaction do
          assign_asset_file(event, (input.asset_file_id if input.has_asset_file_id?))
          assign_input(event, input)
          event.save!
        end
        ProcessSponsorEventEditJob.perform_later(Must.expect(event.last_editing_history))

        Rk::SponsorApp::SponsorServiceUpdateSponsorEventResponse.new(sponsor_event: sponsor_event_message(event))
      end

      authorize :sponsorship
      #: () -> Rk::SponsorApp::SponsorServiceWithdrawSponsorEventResponse
      def withdraw_sponsor_event
        require_event_submission_open!
        event = find_editable_sponsor_event

        event.status = :withdrawn
        event.save!
        ProcessSponsorEventEditJob.perform_later(Must.expect(event.last_editing_history))

        Rk::SponsorApp::SponsorServiceWithdrawSponsorEventResponse.new(sponsor_event: sponsor_event_message(event))
      end

      #: () -> SponsorEvent
      private def find_sponsor_event
        id = connect_request.id #: Integer
        current_sponsorship.sponsor_events.find_by(id:) || raise(Errors::NotFound.new(detail: "The sponsorship has no event #{id}."))
      end

      #: () -> SponsorEvent
      private def find_editable_sponsor_event
        event = find_sponsor_event
        return event if event.editable_by_sponsor?

        raise Errors::FailedPrecondition.new(detail: I18n.t('sponsor_events.update.withdrawn_not_editable'))
      end

      # Slug, status, co-hosts, link name and remarks are staff fields, left out of the Input.
      #: (SponsorEvent, Rk::SponsorApp::SponsorEventInput) -> void
      private def assign_input(event, input)
        event.assign_attributes(
          title: input.title,
          starts_at: Must.because(input.starts_at) { 'buf.validate requires starts_at' }.to_time,
          url: input.url,
          price: input.price,
          capacity: input.capacity,
          location_en: input.location_en,
          location_local: input.location_local,
        )
      end

      # The image after an update: none removes it, the same file keeps it, and another file takes
      # its place. The old file's object leaves the storage once the transaction commits.
      #: (SponsorEvent, Integer?) -> void
      private def assign_asset_file(event, asset_file_id)
        current = event.asset_file
        return if current && current.id == asset_file_id

        replacement = (find_unattached_asset_file(asset_file_id) if asset_file_id)
        current&.destroy!
        event.reload_asset_file
        event.asset_file = replacement if replacement
      end

      # An image this sponsorship uploaded that no event has claimed.
      #: (Integer) -> SponsorEventAssetFile
      private def find_unattached_asset_file(id)
        SponsorEventAssetFile.find_by(id:, sponsor_event: nil, sponsorship: current_sponsorship) ||
          raise(Errors::NotFound.new(detail: "The sponsorship has no unclaimed event image #{id}."))
      end

      #: (SponsorEvent) -> Rk::SponsorApp::SponsorEvent
      private def sponsor_event_message(event)
        Api::SponsorEventResource.new(event, params: {submission_open: !!event_conference.event_submission_open?}).as_protobuf
      end
    end
  end
end
