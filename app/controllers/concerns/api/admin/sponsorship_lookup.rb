# typed: strict
# frozen_string_literal: true

module Api
  module Admin
    # For RPCs under `authorize :conference` whose request names a sponsorship in `sponsorship_id`.
    # @requires_ancestor: Api::Admin::ApplicationController
    module SponsorshipLookup
      # The sponsorship the request names. One of another conference is not found, as the policy
      # admitted the staff member to this conference only.
      #: () -> Sponsorship
      private def find_sponsorship
        id = connect_request.sponsorship_id #: Integer
        conference.sponsorships.find_by(id:) || raise(Errors::NotFound.new(
          detail: "The conference #{conference.slug.inspect} has no sponsorship #{id}.",
        ))
      end
    end
  end
end
