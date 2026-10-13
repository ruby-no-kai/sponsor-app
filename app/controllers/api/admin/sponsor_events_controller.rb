# typed: strict
# frozen_string_literal: true

module Api
  module Admin
    class SponsorEventsController < Api::Admin::ApplicationController
      include Api::Admin::SponsorEventLookup

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceListSponsorEventsResponse
      def list_sponsor_events
        # The status column orders statuses as SponsorEventStatus lists them.
        events = conference.sponsor_events
          .includes(:asset_file, sponsorship: :organization)
          .order(status: :asc, starts_at: :asc, id: :asc)
          .to_a

        Rk::SponsorApp::AdminServiceListSponsorEventsResponse.new(sponsor_events: admin_sponsor_event_messages(events))
      end

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceGetSponsorEventResponse
      def get_sponsor_event
        Rk::SponsorApp::AdminServiceGetSponsorEventResponse.new(
          sponsor_event: admin_sponsor_event_messages([find_sponsor_event]).sole,
        )
      end

      # Staff may change a withdrawn event, which the sponsor's own form refuses.
      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceUpdateSponsorEventResponse
      def update_sponsor_event
        input = connect_request.input #: Rk::SponsorApp::AdminSponsorEventInput
        event = find_sponsor_event
        assign_input(event, input)
        event.staff = current_staff
        event.save!
        ProcessSponsorEventEditJob.perform_later(event.last_editing_history)

        Rk::SponsorApp::AdminServiceUpdateSponsorEventResponse.new(
          sponsor_event: admin_sponsor_event_messages([event.reload]).sole,
        )
      end

      #: (SponsorEvent, Rk::SponsorApp::AdminSponsorEventInput) -> void
      private def assign_input(event, input)
        event.assign_attributes(
          title: input.title,
          slug: input.slug,
          starts_at: Must.because(input.starts_at) { 'buf.validate requires starts_at' }.to_time,
          url: input.url,
          link_name: input.link_name,
          price: input.price,
          capacity: input.capacity,
          location_en: input.location_en,
          location_local: input.location_local,
          status: status_from(input.status),
          co_host_sponsorship_ids: input.co_host_sponsorship_ids.to_a,
          admin_comment: input.admin_comment,
        )
      end

      #: (Symbol | Integer) -> String
      private def status_from(value)
        # The message holds an enum value it does not know as an Integer.
        status = (Api::AdminSponsorEventResource::STATUSES.key(value) if value.is_a?(Symbol))
        Must.because(status) { 'buf.validate admits only the values SponsorEventStatus defines' }
      end

      #: (Array[SponsorEvent]) -> Array[Rk::SponsorApp::AdminSponsorEvent]
      private def admin_sponsor_event_messages(events)
        co_host_ids = events.flat_map(&:co_host_sponsorship_ids)
        co_hosts = conference.sponsorships.includes(:organization).where(id: co_host_ids).index_by(&:id)

        events.map { Api::AdminSponsorEventResource.new(it, params: {co_hosts:}).as_protobuf }
      end
    end
  end
end
