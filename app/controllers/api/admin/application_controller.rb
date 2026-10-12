# typed: strict
# frozen_string_literal: true

module Api
  module Admin
    # Base of the controllers serving AdminService. Every RPC needs a staff session.
    #
    # Policies:
    # - `:any_staff` lets every staff member in.
    # - `:unrestricted_staff` turns away staff restricted to some conferences.
    # - `:conference` loads the conference `conference_slug` names and turns away a restricted staff
    #   member it does not admit. The request message declares `conference_slug` as field 1.
    class ApplicationController < Api::ApplicationController
      connect_service 'rubykaigi.sponsor_app.AdminService'

      #: () -> Array[Symbol]
      def self.rpc_policy_names = [:any_staff, :unrestricted_staff, :conference]

      #: () -> Conference
      private def conference = Must.because(@conference) { 'authorize :conference loads the conference' }

      #: (Symbol?) -> void
      private def require_session!(_policy)
        raise Errors::Unauthenticated.new(detail: 'Sign in to the staff area.') unless current_staff_maybe
      end

      #: (Symbol?) -> void
      private def enforce_policy!(policy)
        case policy
        when nil, :any_staff
          nil
        when :unrestricted_staff
          raise Errors::PermissionDenied.new(detail: 'Restricted staff cannot use this.') if current_staff.restricted?
        when :conference
          authorize_conference!
        else
          raise ArgumentError, "unknown policy #{policy.inspect}"
        end
      end

      #: () -> void
      private def authorize_conference!
        slug = connect_request.conference_slug #: String
        conference = Conference.find_by(slug:)
        raise Errors::NotFound.new(detail: "No conference has the slug #{slug.inspect}.") unless conference
        unless current_staff.conference_accessible?(conference)
          raise Errors::PermissionDenied.new(detail: "Your staff access does not cover the conference #{slug.inspect}.")
        end

        @conference = conference #: Conference?
        set_sentry_conference(conference)
      end
    end
  end
end
