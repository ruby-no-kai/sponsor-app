# typed: strict
# frozen_string_literal: true

module Api
  module Sponsor
    class ConferencesController < Api::Sponsor::ApplicationController
      # Unlike the HAML landing page, leaves the session alone: a GET has no side effects.
      authorize :public
      #: () -> Rk::SponsorApp::SponsorServiceListOpenConferencesResponse
      def list_open_conferences
        conferences = Conference.application_open.publicly_visible.order(id: :asc)

        Rk::SponsorApp::SponsorServiceListOpenConferencesResponse.new(
          conferences: conferences.map { Api::ConferenceResource.new(it).as_protobuf },
        )
      end
    end
  end
end
