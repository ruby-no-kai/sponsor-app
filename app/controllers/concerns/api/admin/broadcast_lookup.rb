# typed: strict
# frozen_string_literal: true

module Api
  module Admin
    # For RPCs under `authorize :conference` whose request names a broadcast in `broadcast_id`.
    # @requires_ancestor: Api::Admin::ApplicationController
    module BroadcastLookup
      # The broadcast the request names. One of another conference is not found, as the policy
      # admitted the staff member to this conference only.
      #: () -> Broadcast
      private def find_broadcast
        id = connect_request.broadcast_id #: Integer
        conference.broadcasts.find_by(id:) || raise(Errors::NotFound.new(
          detail: "The conference #{conference.slug.inspect} has no broadcast #{id}.",
        ))
      end
    end
  end
end
