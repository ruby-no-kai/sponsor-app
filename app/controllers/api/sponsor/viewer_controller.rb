# typed: strict
# frozen_string_literal: true

module Api
  module Sponsor
    class ViewerController < Api::Sponsor::ApplicationController
      authorize :public
      #: () -> Rk::SponsorApp::SponsorServiceGetViewerResponse
      def get_viewer
        signed_in = session_sponsorship_ids.any?
        viewer = SponsorViewer.new(
          email: (session[:email] if signed_in),
          staff: !current_staff_maybe.nil?,
          sponsorships: Sponsorship.includes(:conference).where(id: session_sponsorship_ids).not_withdrawn.order(id: :desc).to_a,
          locale: I18n.locale.to_s,
        )

        Rk::SponsorApp::SponsorServiceGetViewerResponse.new(viewer: Api::SponsorViewerResource.new(viewer).as_protobuf)
      end

      # A staff session in the same cookie stays, as AdminService.SignOut keeps this one. The email
      # and the logos uploaded before applying belong to the contact, so they go too.
      authorize :public
      #: () -> Rk::SponsorApp::SponsorServiceSignOutResponse
      def sign_out
        [:sponsorship_ids, :sponsorship_id, :session_token_id, :email, :asset_file_ids].each { session.delete(it) }
        Rk::SponsorApp::SponsorServiceSignOutResponse.new
      end
    end
  end
end
