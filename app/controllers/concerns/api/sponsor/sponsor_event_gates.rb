# typed: strict
# frozen_string_literal: true

module Api
  module Sponsor
    # What every RPC on a sponsor's events asks of the sponsorship and the conference.
    # @requires_ancestor: Api::Sponsor::ApplicationController
    module SponsorEventGates
      #: () -> Conference
      private def event_conference = Must.expect(current_sponsorship.conference)

      #: () -> void
      private def require_accepted_sponsorship!
        return if current_sponsorship.accepted?

        raise Errors::FailedPrecondition.new(detail: I18n.t('sponsor_events.sponsorship_not_accepted'))
      end

      # For the RPCs that change an event or its image.
      #: () -> void
      private def require_event_submission_open!
        require_accepted_sponsorship!
        return if event_conference.event_submission_open?

        raise Errors::FailedPrecondition.new(detail: I18n.t('sponsor_events.event_submission_not_open'))
      end
    end
  end
end
