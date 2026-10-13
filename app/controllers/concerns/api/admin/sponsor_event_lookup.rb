# typed: strict
# frozen_string_literal: true

module Api
  module Admin
    # For RPCs under `authorize :conference` whose request names an event in `sponsor_event_id`.
    # @requires_ancestor: Api::Admin::ApplicationController
    module SponsorEventLookup
      # The event the request names. One of another conference is not found, as the policy
      # admitted the staff member to this conference only.
      #: () -> SponsorEvent
      private def find_sponsor_event
        id = connect_request.sponsor_event_id #: Integer
        conference.sponsor_events.find_by(id:) || raise(Errors::NotFound.new(
          detail: "The conference #{conference.slug.inspect} has no event #{id}.",
        ))
      end
    end
  end
end
