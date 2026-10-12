# typed: strict
# frozen_string_literal: true

module Api
  module Admin
    class ViewerController < Api::Admin::ApplicationController
      authorize :any_staff
      #: () -> Rk::SponsorApp::AdminServiceGetViewerResponse
      def get_viewer
        Rk::SponsorApp::AdminServiceGetViewerResponse.new(staff: Api::StaffResource.new(current_staff).as_protobuf)
      end

      # A sponsor session in the same cookie stays signed in.
      authorize :any_staff
      #: () -> Rk::SponsorApp::AdminServiceSignOutResponse
      def sign_out
        session.delete(:staff_id)
        Rk::SponsorApp::AdminServiceSignOutResponse.new
      end
    end
  end
end
