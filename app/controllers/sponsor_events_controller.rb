class SponsorEventsController < ApplicationController
  include Rails.application.routes.url_helpers

  before_action :require_sponsorship_session
  before_action :require_event_submission_open
  before_action :require_accepted_sponsorship
  before_action :set_sponsor_event, only: %i(show edit update destroy)

  def new
    @sponsor_event = current_sponsorship.sponsor_events.build
  end

  def create
    @sponsor_event = current_sponsorship.sponsor_events.build(sponsor_event_params)
    @sponsor_event.policy_acknowledged_at = Time.zone.now if params[:sponsor_event][:policy_agreement] == '1'

    if @sponsor_event.save
      ProcessSponsorEventEditJob.perform_later(@sponsor_event.last_editing_history)
      redirect_to user_conference_sponsorship_event_path(conference: current_conference, id: @sponsor_event), notice: t('.notice')
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
    unless @sponsor_event.editable_by_sponsor?
      redirect_to user_conference_sponsorship_event_path(conference: current_conference, id: @sponsor_event), alert: t('.withdrawn_not_editable')
    end
  end

  def update
    unless @sponsor_event.editable_by_sponsor?
      redirect_to user_conference_sponsorship_event_path(conference: current_conference, id: @sponsor_event), alert: t('.withdrawn_not_editable')
      return
    end

    if @sponsor_event.update(sponsor_event_params)
      ProcessSponsorEventEditJob.perform_later(@sponsor_event.last_editing_history)
      redirect_to user_conference_sponsorship_event_path(conference: current_conference, id: @sponsor_event), notice: t('.notice')
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    unless @sponsor_event.editable_by_sponsor?
      redirect_to user_conference_sponsorship_event_path(conference: current_conference, id: @sponsor_event), alert: t('.withdrawn_not_editable')
      return
    end

    @sponsor_event.status = :withdrawn
    @sponsor_event.save!
    ProcessSponsorEventEditJob.perform_later(@sponsor_event.last_editing_history)
    redirect_to user_conference_sponsorship_path(conference: current_conference), notice: t('.notice')
  end

  private

  def require_event_submission_open
    unless current_conference&.event_submission_open?
      redirect_to user_conference_sponsorship_path(conference: current_conference), alert: t('sponsor_events.event_submission_not_open')
    end
  end

  def require_accepted_sponsorship
    unless current_sponsorship&.accepted?
      redirect_to user_conference_sponsorship_path(conference: current_conference), alert: t('sponsor_events.sponsorship_not_accepted')
    end
  end

  def set_sponsor_event
    @sponsor_event = current_sponsorship.sponsor_events.find(params[:id])
  end

  def sponsor_event_params
    params.require(:sponsor_event).permit(
      :title,
      :starts_at,
      :url,
      :price,
      :capacity,
      :location_en,
      :location_local
    )
  end
end
