# frozen_string_literal: true

class SponsorshipAssetFilesController < ApplicationController
  include AssetFileSessionable

  before_action :set_conference
  before_action :set_asset_file, only: [:show, :update, :initiate_update]

  def show
    redirect_to @asset_file.download_url, allow_other_host: true
  end

  def update = super

  def create
    return render(status: :forbidden, json: {error: 403}) if current_sponsorship&.asset_file
    return render(status: :forbidden, json: {error: 403}) if !@conference&.amendment_open? && !current_staff

    @asset_file = SponsorshipAssetFile.prepare(conference: @conference)
    @asset_file.content_type = params[:content_type]
    @asset_file.save!
    (session[:asset_file_ids] ||= []) << @asset_file.id
    render json: make_session
  end

  def initiate_update
    return render(status: :forbidden, json: {error: 403}) if !@conference&.amendment_open? && !current_staff

    @asset_file.content_type = params[:content_type] if params[:content_type].present?
    render json: make_session
  end

  private def set_conference
    @conference = current_conference
  end

  private def set_asset_file
    @asset_file = SponsorshipAssetFile
      .available_for_user(
        params[:id],
        session_asset_file_ids: session[:asset_file_ids],
        available_sponsorship_ids: [current_sponsorship&.id].compact,
      )
      .first!
  end

  private def asset_file_report_to_url(asset_file)
    user_conference_sponsorship_asset_file_path(@conference, asset_file)
  end
end
