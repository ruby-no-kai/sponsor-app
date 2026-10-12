# typed: strict
# frozen_string_literal: true

module Api
  module Admin
    class FormDescriptionsController < Api::Admin::ApplicationController
      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceGetFormDescriptionResponse
      def get_form_description
        locale = connect_request.locale #: String

        Rk::SponsorApp::AdminServiceGetFormDescriptionResponse.new(
          form_description: form_description_message(find_form_description(locale)),
        )
      end

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceCreateFormDescriptionResponse
      def create_form_description
        input = connect_request.input #: Rk::SponsorApp::FormDescriptionInput
        form_description = conference.form_descriptions.build
        save_input!(form_description, input)

        Rk::SponsorApp::AdminServiceCreateFormDescriptionResponse.new(
          form_description: form_description_message(form_description),
        )
      end

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceUpdateFormDescriptionResponse
      def update_form_description
        locale = connect_request.locale #: String
        input = connect_request.input #: Rk::SponsorApp::FormDescriptionInput
        form_description = find_form_description(locale)
        save_input!(form_description, input)

        Rk::SponsorApp::AdminServiceUpdateFormDescriptionResponse.new(
          form_description: form_description_message(form_description),
        )
      end

      #: (String) -> FormDescription
      private def find_form_description(locale)
        conference.form_descriptions.find_by(locale:) || raise(Errors::NotFound.new(
          detail: "The conference #{conference.slug.inspect} has no form description in #{locale.inspect}.",
        ))
      end

      # A validation failure raises ActiveRecord::RecordInvalid, which is answered as
      # Errors::InvalidRecord on the input's fields.
      #: (FormDescription, Rk::SponsorApp::FormDescriptionInput) -> void
      private def save_input!(form_description, input)
        form_description.assign_attributes(
          locale: input.locale,
          head: input.head,
          plan_help: input.plan_help,
          booth_help: input.booth_help,
          policy_help: input.policy_help,
          ticket_help: input.ticket_help,
          sponsor_event_help: input.sponsor_event_help,
          event_policy: input.event_policy,
          fallback_options: internal_fallback_options(input.fallback_options),
        )
        form_description.save!
      rescue ActiveRecord::RecordNotUnique
        raise Errors::Conflict.new(
          detail: "The conference #{conference.slug.inspect} already has a form description in #{input.locale.inspect}.",
        )
      end

      # Copied field by field, as the column's message is storage and free to differ from the API's.
      #: (Google::Protobuf::RepeatedField[Rk::SponsorApp::FallbackOption]) -> Rk::SponsorApp::Internal::FallbackOptions
      private def internal_fallback_options(options)
        Rk::SponsorApp::Internal::FallbackOptions.new(
          options: options.map do |option|
            Rk::SponsorApp::Internal::FallbackOption.new(
              value: option.value,
              name: option.name,
              conditions: option.conditions.map do |condition|
                Rk::SponsorApp::Internal::FallbackOption::Condition.new(
                  plans: condition.plans.to_a,
                  booth_request: condition.has_booth_request? ? condition.booth_request : nil,
                )
              end,
              priority_human: option.priority_human.to_a,
            )
          end,
        )
      end

      #: (FormDescription) -> Rk::SponsorApp::FormDescription
      private def form_description_message(form_description)
        Api::FormDescriptionResource.new(form_description).as_protobuf
      end
    end
  end
end
