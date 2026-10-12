# typed: strict
# frozen_string_literal: true

module Api
  module Admin
    # Base of the controllers serving AdminService. Every RPC needs a staff session.
    #
    # Policies:
    # - `:any_staff` lets every staff member in.
    # - `:unrestricted_staff` turns away staff restricted to some conferences.
    class ApplicationController < Api::ApplicationController
      connect_service 'rubykaigi.sponsor_app.AdminService'

      #: () -> Array[Symbol]
      def self.rpc_policy_names = [:any_staff, :unrestricted_staff]

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
        else
          raise ArgumentError, "unknown policy #{policy.inspect}"
        end
      end
    end
  end
end
