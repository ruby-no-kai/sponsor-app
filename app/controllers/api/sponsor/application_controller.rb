# typed: strict
# frozen_string_literal: true

module Api
  module Sponsor
    # Base of the controllers serving SponsorService.
    #
    # Policies:
    # - `:public` serves anyone, signed in or not.
    # - `:sponsorship` needs a sponsor session, and loads the sponsorship it covers in the conference
    #   `conference_slug` names. The request message declares `conference_slug` as field 1.
    class ApplicationController < Api::ApplicationController
      connect_service 'rubykaigi.sponsor_app.SponsorService'

      #: () -> Array[Symbol]
      def self.rpc_policy_names = [:sponsorship, :public]

      # Sponsorships the sponsor session covers, empty without one.
      #: () -> Array[Integer]
      private def session_sponsorship_ids = Array(session[:sponsorship_ids])

      # TODO: consolidate with root ApplicationController to eliminate duplicates
      #: () -> Sponsorship?
      private def current_sponsorship_maybe
        return @current_sponsorship if defined?(@current_sponsorship)

        slug = connect_request.conference_slug #: String
        @current_sponsorship = Sponsorship.where(id: session_sponsorship_ids)
          .joins(:conference)
          .merge(Conference.where(slug:))
          .not_withdrawn
          .first #: Sponsorship?
      end

      #: () -> Sponsorship
      private def current_sponsorship = Must.because(current_sponsorship_maybe) { 'authorize :sponsorship loads the sponsorship' }

      #: (Symbol?) -> void
      private def require_session!(policy)
        case policy
        when nil, :public
          nil
        when :sponsorship
          raise Errors::Unauthenticated.new(detail: 'Sign in with the link emailed to you.') if session_sponsorship_ids.empty?
        else
          raise ArgumentError, "unknown policy #{policy.inspect}"
        end
      end

      #: (Symbol?) -> void
      private def enforce_policy!(policy)
        case policy
        when nil, :public
          nil
        when :sponsorship
          sponsorship = current_sponsorship_maybe
          raise Errors::NotFound.new(detail: 'You have no sponsorship for this conference.') unless sponsorship

          set_sentry_sponsorship(sponsorship)
        else
          raise ArgumentError, "unknown policy #{policy.inspect}"
        end
      end

      #: (Sponsorship) -> void
      private def set_sentry_sponsorship(sponsorship)
        Sentry.configure_scope do |scope|
          scope.set_context('sponsor-app.sponsor', {id: sponsorship.id, name: sponsorship.name})
        end
        Sentry.set_user(id: sponsorship.id.to_s, email: session[:email]) unless current_staff_maybe
        set_sentry_conference(Must.expect(sponsorship.conference))
      end
    end
  end
end
