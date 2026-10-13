# typed: strict
# frozen_string_literal: true

class SponsorshipAssetFilesController < ApplicationController
  include AssetFileSessionable

  before_action :set_conference
  before_action :set_asset_file, only: [:show, :update, :initiate_update]

  #: () -> void
  def show
    redirect_to asset_file.download_url, allow_other_host: true
  end

  #: () -> void
  def update = super

  #: () -> void
  def create
    return render(status: :forbidden, json: {error: 403}) if current_sponsorship_maybe&.asset_file
    return render(status: :forbidden, json: {error: 403}) if !conference.amendment_open? && !current_staff_maybe

    @asset_file = SponsorshipAssetFile.prepare(conference:)
    asset_file.content_type = params[:content_type]
    asset_file.save!
    (session[:asset_file_ids] ||= []) << asset_file.id
    render proto_json: make_session
  end

  #: () -> void
  def initiate_update
    return render(status: :forbidden, json: {error: 403}) if !conference.amendment_open? && !current_staff_maybe

    asset_file.content_type = params[:content_type] if params[:content_type].present?
    render proto_json: make_session
  end

  #: () -> void
  private def set_conference
    @conference = current_conference_maybe || raise(ActiveRecord::RecordNotFound) #: Conference?
  end

  #: () -> void
  private def set_asset_file
    @asset_file = SponsorshipAssetFile
      .available_for_user(
        params[:id],
        session_asset_file_ids: session[:asset_file_ids],
        available_sponsorship_ids: [current_sponsorship_maybe&.id].compact,
      )
      .first! #: SponsorshipAssetFile?
  end

  #: (AssetFileSessionable::asset_file_record) -> String
  private def asset_file_report_to_url(asset_file)
    user_conference_sponsorship_asset_file_path(conference, asset_file)
  end

  #: () -> Conference
  private def conference = Must.because(@conference) { "set_conference runs before every action" }

  #: () -> SponsorshipAssetFile
  private def asset_file = Must.because(@asset_file) { "set_asset_file or create assigns @asset_file" }
end
