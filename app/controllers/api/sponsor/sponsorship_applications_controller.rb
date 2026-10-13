# typed: strict
# frozen_string_literal: true

module Api
  module Sponsor
    # Applying for a sponsorship and amending the application, as the HAML application form does.
    class SponsorshipApplicationsController < Api::Sponsor::ApplicationController
      include Api::Sponsor::ApplicationLookup
      include Api::SponsorshipInputAssignable

      # Unlike the HAML page, answers when applications are closed or the contact has applied
      # already, so the client can say so. The plans and texts of a closed conference may be drafts,
      # so only staff get them.
      authorize :public
      #: () -> Rk::SponsorApp::SponsorServiceGetApplicationFormResponse
      def get_application_form
        invite_code = connect_request.invite_code #: String
        affiliation = connect_request.affiliation #: String
        copy_id = (connect_request.sponsorship_id_to_copy if connect_request.has_sponsorship_id_to_copy?) #: Integer?
        conference = find_application_conference(invite_code)
        application_open = !!conference.application_open?
        staff_override = !application_open && !current_staff_maybe.nil?
        closed = !application_open && !staff_override

        response = Rk::SponsorApp::SponsorServiceGetApplicationFormResponse.new(
          form: closed ? closed_application_form(conference) : application_form(conference),
          application_open:,
          staff_override:,
          already_applied: !current_sponsorship_maybe.nil?,
          copy_sources: session_sponsorships.map { Api::SponsorViewerSponsorshipResource.new(it).as_protobuf },
          copied_application: (copied_application(copy_id) unless closed),
        )
        affiliated_organization(affiliation)&.then { response.affiliated_organization_name = it.name }
        response
      end

      authorize :public
      #: () -> Rk::SponsorApp::SponsorServiceCreateSponsorshipResponse
      def create_sponsorship
        invite_code = connect_request.invite_code #: String
        affiliation = connect_request.affiliation #: String
        input = connect_request.input #: Rk::SponsorApp::SponsorshipInput
        conference = find_application_conference(invite_code)
        if current_sponsorship_maybe
          raise Errors::FailedPrecondition.new(detail: "You have applied to the conference #{conference.slug.inspect} already.")
        end
        if !conference.application_open? && !current_staff_maybe
          raise Errors::FailedPrecondition.new(detail: "The conference #{conference.slug.inspect} takes no applications now.")
        end
        require_form_description!(conference)

        sponsorship = Sponsorship.new(conference:)
        assign_input(sponsorship, conference, input)
        sponsorship.locale = I18n.locale.to_s
        sponsorship.assume_organization(affiliated_organization: affiliated_organization(affiliation))
        sponsorship.accept if sponsorship.plan&.auto_acceptance && !sponsorship.organization&.auto_acceptance_disabled
        asset_file = save_application(sponsorship, conference, input.asset_file_id)

        session[:sponsorship_ids] = [sponsorship.id, *session_sponsorship_ids]
        session[:email] ||= sponsorship.contact&.email
        session[:asset_file_ids] = session_asset_file_ids - [asset_file.id]
        SponsorshipWelcomeJob.perform_later(sponsorship)

        Rk::SponsorApp::SponsorServiceCreateSponsorshipResponse.new(
          sponsorship: Api::SponsorshipResource.new(sponsorship).as_protobuf,
        )
      end

      #: (Sponsorship, Conference, Rk::SponsorApp::SponsorshipInput) -> void
      private def assign_input(sponsorship, conference, input)
        sponsorship.assign_attributes(
          plan: input_plan(conference, input),
          name: input.name,
          url: input.url,
          profile: input.profile,
          booth_requested: input.booth_requested,
          fallback_option: input.fallback_option,
          number_of_additional_attendees: (input.number_of_additional_attendees if input.has_number_of_additional_attendees?),
        )
        assign_contact(sponsorship, Must.because(input.contact) { 'buf.validate requires the contact' })
        assign_alternate_billing_contact(sponsorship, input.alternate_billing_contact)
        assign_requests(sponsorship, input)
      end

      # Saves a new application with its logo, copying another sponsorship's. A refused application
      # rolls back the copied file record, and the copied object stays in the storage.
      #: (Sponsorship, Conference, Integer) -> SponsorshipAssetFile
      private def save_application(sponsorship, conference, asset_file_id)
        ActiveRecord::Base.transaction do
          source = find_application_asset_file(asset_file_id, conference, sponsorship_ids: session_sponsorships.ids)
          asset_file = source.sponsorship_id ? source.copy_to!(conference) : source
          sponsorship.asset_file = asset_file
          sponsorship.save!(context: :update_by_user)
          asset_file
        end
      rescue ActiveRecord::RecordNotUnique
        # The unique index on (conference_id, organization_id) catches what the validation raced.
        raise Errors::Conflict.new(
          detail: "Another application from your organization to the conference #{conference.slug.inspect} landed first.",
        )
      end

      # What an application form shows besides the answers.
      #: (Conference) -> Rk::SponsorApp::ApplicationForm
      private def application_form(conference)
        Rk::SponsorApp::ApplicationForm.new(
          conference: Api::ConferenceResource.new(conference).as_protobuf,
          plans: conference.plans.with_active_sponsorship_count.map { Api::ApplicationPlanResource.new(it).as_protobuf },
          description: Api::FormDescriptionResource.new(require_form_description!(conference)).as_protobuf,
        )
      end

      # The conference alone, for saying when it takes applications.
      #: (Conference) -> Rk::SponsorApp::ApplicationForm
      private def closed_application_form(conference)
        Rk::SponsorApp::ApplicationForm.new(conference: Api::ConferenceResource.new(conference).as_protobuf)
      end

      # A conference takes applications only once its form is described. Sponsorship's fallback
      # option rule would otherwise raise RecordNotFound, answered as if the conference were missing.
      #: (Conference) -> FormDescription
      private def require_form_description!(conference)
        conference.form_description_for_locale_maybe || raise(Errors::FailedPrecondition.new(
          detail: "The conference #{conference.slug.inspect} has no application form yet.",
        ))
      end

      # The answers of a sponsorship the session covers that carry over to a new application. A
      # withdrawn one is not offered, as CreateSponsorship would not copy its logo.
      #: (Integer?) -> Rk::SponsorApp::SponsorshipApplication?
      private def copied_application(id)
        return unless id

        source = session_sponsorships.find_by(id:)
        return unless source

        # The source keeps its logo, which the new application copies when it is saved.
        copied = Api::SponsorshipApplicationResource.new(Sponsorship.new(source.attributes_for_copy.except(:asset_file_id))).as_protobuf
        source.asset_file&.then { copied.asset_file = Api::SponsorshipAssetFileResource.new(it).as_protobuf }
        copied
      end
    end
  end
end
