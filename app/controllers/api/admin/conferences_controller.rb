# typed: strict
# frozen_string_literal: true

module Api
  module Admin
    class ConferencesController < Api::Admin::ApplicationController
      # Open to restricted staff, who see only the conferences they may manage.
      authorize :any_staff
      #: () -> Rk::SponsorApp::AdminServiceListConferencesResponse
      def list_conferences
        conferences = Conference.order(id: :desc).select { current_staff.conference_accessible?(it) }

        Rk::SponsorApp::AdminServiceListConferencesResponse.new(
          conferences: conferences.map { Api::ConferenceResource.new(it).as_protobuf },
        )
      end

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceGetConferenceResponse
      def get_conference
        Rk::SponsorApp::AdminServiceGetConferenceResponse.new(conference: Api::ConferenceResource.new(conference).as_protobuf)
      end
    end
  end
end
