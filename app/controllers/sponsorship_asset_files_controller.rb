class SponsorshipAssetFilesController < ApplicationController
  before_action :set_conference
  before_action :set_asset_file, only: [:show, :update, :initiate_update]

  def show
    redirect_to @asset_file.download_url(), allow_other_host: true
  end

  def create
    return render(status: 403, json: {error: 403}) if current_sponsorship&.asset_file
    return render(status: 403, json: {error: 403}) if !@conference&.amendment_open? && !current_staff
    @asset_file = SponsorshipAssetFile.create!(prefix: "c-#{@conference.id}/")
    (session[:asset_file_ids] ||= []) << @asset_file.id
    render json: make_session
  end

  def update
    @asset_file.assign_attributes(params.permit(:version_id))
    @asset_file.extension = params[:extension]&.then { _1.downcase.gsub(/[^a-z0-9]/,'') } || 'unknown'

    @asset_file.update_object_header()

    if @asset_file.save
      render json: {ok: true}
    else
      render status: 422, json: {ok: false, messages: @asset_file.errors.full_messages}
    end
  end

  def initiate_update
    return render(status: 403, json: {error: 403}) if !@conference&.amendment_open? && !current_staff
    render json: make_session
  end

  private def set_conference
    @conference = current_conference
  end

  private def set_asset_file
    @asset_file = SponsorshipAssetFile
      .where(id: params[:id])
      .merge(
        SponsorshipAssetFile
          .where(sponsorship_id: nil, id: session[:asset_file_ids] || [])
          .or(SponsorshipAssetFile.where(sponsorship_id: [current_sponsorship&.id].compact))
      )
      .first!
  end

  private def make_session
    @asset_file.make_session.merge(
      report_to: user_conference_sponsorship_asset_file_path(@conference, @asset_file)
    )
  end
end
