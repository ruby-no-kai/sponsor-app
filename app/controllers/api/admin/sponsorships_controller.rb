# typed: strict
# frozen_string_literal: true

module Api
  module Admin
    class SponsorshipsController < Api::Admin::ApplicationController
      include Api::Admin::SponsorshipLookup

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
          plan: input_plan(input),
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

        contact = Must.because(input.contact) { 'buf.validate requires the contact' }
        stored_contact = Must.because(sponsorship.contact) { 'a saved sponsorship validates the presence of its contact' }
        stored_contact.assign_attributes(
          email: contact.email,
          email_cc: optional_string((contact.email_cc if contact.has_email_cc?), stored_contact.email_cc),
          address: contact.address,
          organization: contact.organization,
          unit: optional_string((contact.unit if contact.has_unit?), stored_contact.unit),
          name: contact.name,
        )

        if (billing_contact = input.alternate_billing_contact)
          stored_billing = sponsorship.alternate_billing_contact || sponsorship.build_alternate_billing_contact
          stored_billing.assign_attributes(
            email: billing_contact.email,
            address: billing_contact.address,
            organization: billing_contact.organization,
            unit: optional_string((billing_contact.unit if billing_contact.has_unit?), stored_billing.unit),
            name: billing_contact.name,
          )
        else
          sponsorship.alternate_billing_contact&.mark_for_destruction
        end

        assign_request(sponsorship.customization_request, input.customization_request) { sponsorship.build_customization_request }
        assign_request(sponsorship.billing_request, input.billing_request) { sponsorship.build_billing_request }
        assign_request(sponsorship.note, input.note) { sponsorship.build_note }
      end

      # The HAML forms store a blank optional string as "", so an absent one leaves a blank value as it is.
      #: (String?, String?) -> String?
      private def optional_string(given, stored)
        given || (stored if stored.blank?)
      end

      #: (Rk::SponsorApp::AdminSponsorshipInput) -> Plan?
      private def input_plan(input)
        return unless input.has_plan_id?

        plan_id = input.plan_id
        conference.plans.find_by(id: plan_id) || raise(Errors::NotFound.new(
          detail: "The conference #{conference.slug.inspect} has no plan #{plan_id}.",
        ))
      end

      # A blank body removes the request, as the sponsor's own form does.
      #: (SponsorshipRequest?, String) { () -> SponsorshipRequest } -> void
      private def assign_request(request, body, &build)
        if body.blank?
          request&.mark_for_destruction
        else
          (request || build.call).body = body
        end
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
