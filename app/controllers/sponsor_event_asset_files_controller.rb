class SponsorEventAssetFilesController < ApplicationController
  include AssetFileSessionable

  before_action :require_sponsorship_session
  before_action :require_accepted_sponsorship
  before_action :set_conference
  before_action :set_asset_file, only: %i(show update initiate_update)

  def show
    redirect_to @asset_file.download_url, allow_other_host: true
  end

  def create
    return render(status: 403, json: { error: 403 }) if !current_conference&.event_submission_open?
    @asset_file = SponsorEventAssetFile.prepare(conference: @conference, sponsorship: current_sponsorship)
    @asset_file.save!
    (session[:event_asset_file_ids] ||= []) << @asset_file.id
    render json: make_session
  end

  def initiate_update
    return render(status: 403, json: { error: 403 }) if !current_conference&.event_submission_open?
    render json: make_session
  end

  private

  def set_conference
    @conference = current_conference
  end

  def set_asset_file
    @asset_file = SponsorEventAssetFile
      .where(id: params[:id])
      .where(
        SponsorEventAssetFile.where(sponsor_event_id: nil, id: session[:event_asset_file_ids] || [])
          .or(SponsorEventAssetFile.joins(:sponsor_event).where(sponsor_events: { sponsorship_id: current_sponsorship.id }))
      )
      .first!
  end

  def require_accepted_sponsorship
    unless current_sponsorship&.accepted?
      render status: 403, json: { error: 'sponsorship_not_accepted' }
    end
  end

  def asset_file_report_to_url(asset_file)
    user_conference_event_asset_file_path(@conference, asset_file)
  end
end
