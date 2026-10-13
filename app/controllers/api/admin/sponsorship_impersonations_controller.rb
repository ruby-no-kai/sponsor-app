# typed: strict
# frozen_string_literal: true

module Api
  module Admin
    class SponsorshipImpersonationsController < Api::Admin::ApplicationController
      include Api::Admin::SponsorshipLookup

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceImpersonateSponsorshipResponse
      def impersonate_sponsorship
        enabled = Rails.configuration.x.dev.sponsor_impersonation #: bool?
        raise Errors::NotFound.new(detail: 'Impersonation is available in development only.') unless enabled

        sponsorship = find_sponsorship
        token = SessionToken.create!(
          email: Must.because(sponsorship.contact) { 'a saved sponsorship validates the presence of its contact' }.email,
          expires_at: 1.minute.from_now,
        )

        Rk::SponsorApp::AdminServiceImpersonateSponsorshipResponse.new(claim_path: claim_user_session_path(token))
      end
    end
  end
end
