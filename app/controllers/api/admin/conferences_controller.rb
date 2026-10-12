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
          conferences: conferences.map { admin_conference_message(it) },
        )
      end

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceGetConferenceResponse
      def get_conference
        plans = conference.plans.with_active_sponsorship_count.order(:rank, :id)
        sponsorships = conference.sponsorships.includes(:organization).order(id: :asc)

        Rk::SponsorApp::AdminServiceGetConferenceResponse.new(
          conference: admin_conference_message(conference),
          form_description_locales: conference.form_descriptions.order(id: :asc).pluck(:locale),
          plans: plans.map { Api::PlanSummaryResource.new(it).as_protobuf },
          sponsorships: sponsorships.map { Api::SponsorshipSummaryResource.new(it).as_protobuf },
        )
      end

      #: (Conference) -> Rk::SponsorApp::AdminConference
      private def admin_conference_message(conference)
        application_form_url = new_user_conference_sponsorship_url(conference, **{invite_code: conference.invite_code}.compact)
        Api::AdminConferenceResource.new(conference, params: {application_form_url:}).as_protobuf
      end
    end
  end
end
