class Admin::SponsorEventsController < Admin::ApplicationController
  before_action :set_conference
  before_action :set_sponsor_event, only: %i(show edit update download_asset)

  def index
    @sponsor_events = @conference.sponsor_events
      .includes(:sponsorship)
      .order(status: :asc, starts_at: :asc)
  end

  def show
  end

  def edit
  end

  def download_asset
    asset = @sponsor_event.asset_file
    raise ActiveRecord::RecordNotFound unless asset
    redirect_to asset.download_url, allow_other_host: true
  end

  def update
    @sponsor_event.assign_attributes(sponsor_event_params)
    @sponsor_event.staff = current_staff

    if @sponsor_event.save
      ProcessSponsorEventEditJob.perform_later(@sponsor_event.last_editing_history)
      redirect_to conference_sponsor_event_path(@conference, @sponsor_event), notice: 'Event was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_conference
    @conference = Conference.find_by!(slug: params[:conference_slug])
    check_staff_conference_authorization!(@conference)
  end

  def set_sponsor_event
    @sponsor_event = @conference.sponsor_events.find(params[:id])
    @sponsorship = @sponsor_event.sponsorship
  end

  def sponsor_event_params
    params.require(:sponsor_event).permit(
      :title,
      :starts_at,
      :url,
      :price,
      :capacity,
      :location_en,
      :location_local,
      :slug,
      :status,
      :link_name,
      :admin_comment
    ).tap do |sp|
      if params[:sponsor_event][:co_host_sponsorship_ids].present?
        sp[:co_host_sponsorship_ids] = params[:sponsor_event][:co_host_sponsorship_ids]
          .split(',')
          .map(&:strip)
          .reject(&:blank?)
          .map(&:to_i)
      else
        sp[:co_host_sponsorship_ids] = []
      end
    end
  end
end
