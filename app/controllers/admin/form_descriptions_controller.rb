# typed: true
# frozen_string_literal: true

module Admin
  class FormDescriptionsController < Admin::ApplicationController
    before_action :set_conference
    before_action :set_form_description, only: [:show, :edit, :update]

    def show
    end

    def new
      @form_description = FormDescription.new(conference:)
    end

    def edit
    end

    def create
      @form_description = FormDescription.new(form_description_params)
      @form_description.conference = conference

      respond_to do |format|
        if @form_description.save
          format.html { redirect_to [conference, @form_description], notice: 'Form description was successfully created.' }
        else
          format.html { render :new }
        end
      end
    end

    def update
      respond_to do |format|
        if form_description.update(form_description_params)
          format.html { redirect_to [conference, form_description], notice: 'Form description was successfully updated.' }
        else
          format.html { render :new }
        end
      end
    end

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

    private def set_conference
      @conference = Conference.find_by!(slug: params[:conference_slug])
      check_staff_conference_authorization!(@conference)
    end

    private def set_form_description
      @form_description = FormDescription.where(conference:).find_by!(locale: params[:locale])
    end

    #: () -> Conference
    private def conference = Must.because(@conference) { "set_conference runs before every action" }

    #: () -> FormDescription
    private def form_description = Must.because(@form_description) { "set_form_description runs before show, edit and update" }
  end
end
