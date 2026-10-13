# typed: strict
# frozen_string_literal: true

module Admin
  class FormDescriptionsController < Admin::ApplicationController
    before_action :set_conference
    before_action :set_form_description, only: [:show, :edit, :update]

    #: () -> void
    def show
    end

    #: () -> void
    def new
      @form_description = FormDescription.new(conference:)
    end

    #: () -> void
    def edit
    end

    #: () -> void
    def create
      @form_description = FormDescription.new(conference:)

      respond_to do |format|
        if assign_form_description_params && form_description.save
          format.html { redirect_to [conference, form_description], notice: 'Form description was successfully created.' }
        else
          format.html { render :new }
        end
      end
    end

    #: () -> void
    def update
      respond_to do |format|
        if assign_form_description_params && form_description.save
          format.html { redirect_to [conference, form_description], notice: 'Form description was successfully updated.' }
        else
          format.html { render :new }
        end
      end
    end

    # The fallback_options textarea holds an Internal::FallbackOptions message as JSON. Malformed
    # JSON, or a key the message lacks, is reported on the form rather than raised.
    #: () -> bool
    private def assign_form_description_params
      attributes = form_description_params
      json = attributes.delete(:fallback_options) #: String?
      form_description.assign_attributes(attributes)
      return true if json.nil?

      form_description.fallback_options = if json.blank?
        Rk::SponsorApp::Internal::FallbackOptions.new
      else
        Rk::SponsorApp::Internal::FallbackOptions.decode_json(json)
      end
      true
    rescue Google::Protobuf::ParseError => e
      @fallback_options_json = json #: String?
      form_description.errors.add(:fallback_options, "is not a FallbackOptions message: #{e.message}")
      false
    end

    #: () -> ActionController::Parameters
    private def form_description_params
      params.require(:form_description).permit(
        :locale,
        :head,
        :plan_help,
        :booth_help,
        :policy_help,
        :ticket_help,
        :fallback_options,
        :sponsor_event_help,
        :event_policy,
      )
    end

    #: () -> void
    private def set_conference
      @conference = Conference.find_by!(slug: params[:conference_slug]) #: Conference?
      check_staff_conference_authorization!(conference)
    end

    #: () -> void
    private def set_form_description
      @form_description = FormDescription.where(conference:).find_by!(locale: params[:locale]) #: FormDescription?
    end

    #: () -> Conference
    private def conference = Must.because(@conference) { "set_conference runs before every action" }

    #: () -> FormDescription
    private def form_description = Must.because(@form_description) { "set_form_description or the action sets it" }
  end
end
