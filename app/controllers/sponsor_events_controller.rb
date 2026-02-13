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
    assign_new_asset_file

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

    success = ActiveRecord::Base.transaction do
      handle_asset_file_update
      unless @sponsor_event.update(sponsor_event_params)
        raise ActiveRecord::Rollback
      end
      true
    end

    if success
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

  def assign_new_asset_file
    asset_file_id = params[:sponsor_event][:asset_file_id]
    return if asset_file_id.blank?

    asset_file = SponsorEventAssetFile
      .where(id: asset_file_id, sponsor_event: nil, sponsorship: current_sponsorship)
      .first!
    @sponsor_event.asset_file = asset_file
  end

  def handle_asset_file_update
    asset_file_id = params[:sponsor_event][:asset_file_id]

    if asset_file_id == ""
      @sponsor_event.asset_file&.destroy!
    elsif asset_file_id.present? && asset_file_id.to_i != @sponsor_event.asset_file&.id
      new_file = SponsorEventAssetFile
        .where(id: asset_file_id, sponsor_event: nil, sponsorship: current_sponsorship)
        .first!
      @sponsor_event.asset_file&.destroy!
      @sponsor_event.asset_file = new_file
    end
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
