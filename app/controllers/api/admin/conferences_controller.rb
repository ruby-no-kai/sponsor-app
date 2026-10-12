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

      # A conference's settings decide which staff may manage it and where its data is published, so
      # restricted staff may neither create nor update one.
      authorize :unrestricted_staff
      #: () -> Rk::SponsorApp::AdminServiceCreateConferenceResponse
      def create_conference
        input = connect_request.input #: Rk::SponsorApp::ConferenceInput
        conference = Conference.new
        save_input!(conference, input)

        Rk::SponsorApp::AdminServiceCreateConferenceResponse.new(conference: admin_conference_message(conference))
      end

      authorize :unrestricted_staff
      #: () -> Rk::SponsorApp::AdminServiceUpdateConferenceResponse
      def update_conference
        slug = connect_request.conference_slug #: String
        input = connect_request.input #: Rk::SponsorApp::ConferenceInput
        conference = Conference.find_by(slug:) || raise(Errors::NotFound.new(detail: "No conference has the slug #{slug.inspect}."))
        set_sentry_conference(conference)
        save_input!(conference, input)

        Rk::SponsorApp::AdminServiceUpdateConferenceResponse.new(conference: admin_conference_message(conference))
      end

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceGetAttendeesKeeperResponse
      def get_attendees_keeper
        sponsorships = conference.sponsorships.active.includes(:plan, :organization)
          .sort_by { [-it.total_number_of_attendees, it.id] }
        rows = sponsorships.map { Api::SponsorshipAttendeesResource.new(it).as_protobuf }

        Rk::SponsorApp::AdminServiceGetAttendeesKeeperResponse.new(
          included_attendees: rows.sum(&:included_attendees),
          additional_attendees: rows.sum(&:additional_attendees),
          total_attendees: rows.sum(&:total_attendees),
          sponsorships: rows,
        )
      end

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceListSponsorshipTableRowsResponse
      def list_sponsorship_table_rows
        sponsorships = conference.sponsorships.includes(:plan, :organization).includes_requests.order(id: :asc)

        Rk::SponsorApp::AdminServiceListSponsorshipTableRowsResponse.new(
          sponsorship_table_rows: sponsorships.map { Api::SponsorshipTableRowResource.new(it).as_protobuf },
        )
      end

      # A validation failure raises ActiveRecord::RecordInvalid, which is answered as
      # Errors::InvalidRecord on the input's fields.
      #: (Conference, Rk::SponsorApp::ConferenceInput) -> void
      private def save_input!(conference, input)
        conference.assign_attributes(
          name: input.name,
          slug: input.slug,
          contact_email_address: input.contact_email_address,
          application_opens_at: input.application_opens_at&.to_time,
          application_closes_at: input.application_closes_at&.to_time,
          amendment_closes_at: input.amendment_closes_at&.to_time,
          event_submission_starts_at: input.event_submission_starts_at&.to_time,
          ticket_distribution_starts_at: input.ticket_distribution_starts_at&.to_time,
          pass_retraction_disables_at: input.pass_retraction_disables_at&.to_time,
          no_plan_allowed: input.no_plan_allowed,
          booth_capacity: input.booth_capacity,
          additional_attendees_registration_open: input.additional_attendees_registration_open,
          hidden: input.hidden,
          allow_restricted_access: input.allow_restricted_access,
          github_repo: (input.github_repo if input.has_github_repo?),
          github_repo_images_path: (input.github_repo_images_path if input.has_github_repo_images_path?),
          tito_slug: (input.tito_slug if input.has_tito_slug?),
          tito_booth_paid_flat_discount_amount: BigDecimal(input.tito_booth_paid_flat_discount_amount),
        )
        conference.save!
      rescue ActiveRecord::RecordNotUnique
        # Only a concurrent save gets past the slug's uniqueness validation.
        raise Errors::Conflict.new(detail: "Another conference has the slug #{input.slug.inspect}.")
      end

      #: (Conference) -> Rk::SponsorApp::AdminConference
      private def admin_conference_message(conference)
        application_form_url = new_user_conference_sponsorship_url(conference, **{invite_code: conference.invite_code}.compact)
        Api::AdminConferenceResource.new(conference, params: {application_form_url:}).as_protobuf
      end
    end
  end
end
