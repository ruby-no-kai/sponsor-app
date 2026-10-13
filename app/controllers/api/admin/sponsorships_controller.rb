# typed: strict
# frozen_string_literal: true

module Api
  module Admin
    class SponsorshipsController < Api::Admin::ApplicationController
      include Api::Admin::SponsorshipLookup
      include Api::SponsorshipInputAssignable

      RECENT_STAFF_NOTE_COUNT = 5 #: Integer

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceGetSponsorshipResponse
      def get_sponsorship
        sponsorship = find_sponsorship
        staff_notes = sponsorship.staff_notes.includes(:staff).order(stickiness: :desc, created_at: :desc)
        impersonation_enabled = Rails.configuration.x.dev.sponsor_impersonation #: bool?

        Rk::SponsorApp::AdminServiceGetSponsorshipResponse.new(
          sponsorship: admin_sponsorship_message(sponsorship),
          pinned_staff_notes: staff_notes.where('stickiness > 0').map { staff_note_message(it) },
          recent_staff_notes: staff_notes.where(stickiness: 0).limit(RECENT_STAFF_NOTE_COUNT).map { staff_note_message(it) },
          plan_choices: conference.plans.order(:rank, :id).map { Api::AdminSponsorshipPlanResource.new(it).as_protobuf },
          fallback_option_choices: fallback_option_choices(sponsorship),
          impersonation_enabled: !!impersonation_enabled,
        )
      end

      # Saves in the default validation context, which leaves out the rules the sponsor's own
      # edits are held to, such as plan availability and word limits.
      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceUpdateSponsorshipResponse
      def update_sponsorship
        input = connect_request.input #: Rk::SponsorApp::AdminSponsorshipInput
        sponsorship = find_sponsorship
        assign_input(sponsorship, input)
        sponsorship.staff = current_staff
        sponsorship.save!
        ProcessSponsorshipEditJob.perform_later(sponsorship.last_editing_history)

        Rk::SponsorApp::AdminServiceUpdateSponsorshipResponse.new(
          sponsorship: admin_sponsorship_message(sponsorship.reload),
        )
      end

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceWithdrawSponsorshipResponse
      def withdraw_sponsorship
        sponsorship = find_sponsorship
        if sponsorship.withdrawn?
          raise Errors::FailedPrecondition.new(detail: "The sponsorship #{sponsorship.id} has already withdrawn.")
        end

        sponsorship.staff = current_staff
        sponsorship.withdraw.save!
        ProcessSponsorshipEditJob.perform_later(sponsorship.last_editing_history)

        Rk::SponsorApp::AdminServiceWithdrawSponsorshipResponse.new(
          sponsorship: admin_sponsorship_message(sponsorship),
        )
      end

      #: (Sponsorship, Rk::SponsorApp::AdminSponsorshipInput) -> void
      private def assign_input(sponsorship, input)
        sponsorship.assign_attributes(
          plan: input_plan(conference, input),
          name: input.name,
          url: input.url,
          profile: input.profile,
          booth_requested: input.booth_requested,
          booth_assigned: input.booth_assigned,
          fallback_option: input.fallback_option,
          customization: input.customization,
          customization_name: optional_string((input.customization_name if input.has_customization_name?), sponsorship.customization_name),
          suspended: input.suspended,
          accepted: input.accepted,
          number_of_additional_attendees: (input.number_of_additional_attendees if input.has_number_of_additional_attendees?),
        )
        assign_contact(sponsorship, Must.because(input.contact) { 'buf.validate requires the contact' })
        assign_alternate_billing_contact(sponsorship, input.alternate_billing_contact)
        assign_requests(sponsorship, input)
      end

      #: (Sponsorship) -> Array[Rk::SponsorApp::FallbackOption]
      private def fallback_option_choices(sponsorship)
        form_description = conference.form_description_for_locale_maybe(sponsorship.locale)
        return [] unless form_description

        form_description.fallback_options.options.map { Api::FallbackOptionResource.new(it).as_protobuf }
      end

      #: (Sponsorship) -> Rk::SponsorApp::AdminSponsorship
      private def admin_sponsorship_message(sponsorship)
        Api::AdminSponsorshipResource.new(sponsorship).as_protobuf
      end

      #: (SponsorshipStaffNote) -> Rk::SponsorApp::SponsorshipStaffNote
      private def staff_note_message(staff_note)
        Api::SponsorshipStaffNoteResource.new(staff_note).as_protobuf
      end
    end
  end
end
