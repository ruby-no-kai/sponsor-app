class Admin::FormDescriptionsController < Admin::ApplicationController
  before_action :set_conference
  before_action :set_form_description, only: [:show, :edit, :update]

  def show
  end

  def new
    @form_description = FormDescription.new(conference: @conference)
  end

  def edit
  end

  def create
    @form_description = FormDescription.new(form_description_params)
    @form_description.conference = @conference

    respond_to do |format|
      if @form_description.save
        format.html { redirect_to [@conference, @form_description], notice: 'Form description was successfully created.' }
      else
        format.html { render :new }
      end
    end
  end

  def update
    respond_to do |format|
      if @form_description.update(form_description_params)
        format.html { redirect_to [@conference, @form_description], notice: 'Form description was successfully updated.' }
      else
        format.html { render :new }
      end
    end
  end

  private

  def form_description_params
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

  def set_conference
    @conference = Conference.find_by!(slug: params[:conference_slug])
    check_staff_conference_authorization!(@conference)
  end

  def set_form_description
    @form_description = FormDescription.where(conference: @conference).find_by!(locale: params[:locale])
  end
end
