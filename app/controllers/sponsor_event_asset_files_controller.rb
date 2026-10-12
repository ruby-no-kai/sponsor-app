# typed: strict
# frozen_string_literal: true

class SponsorEventAssetFilesController < ApplicationController
  include AssetFileSessionable

  before_action :require_sponsorship_session
  before_action :require_accepted_sponsorship
  before_action :set_conference
  before_action :set_asset_file, only: %i(show update initiate_update)

  #: () -> void
  def show
    redirect_to asset_file.download_url, allow_other_host: true
  end

  #: () -> void
  def update = super

  #: () -> void
  def create
    @asset_file = SponsorEventAssetFile.prepare(conference:, sponsorship: current_sponsorship)
    asset_file.content_type = params[:content_type]
    asset_file.save!
    render json: make_session
  end

  #: () -> void
  def initiate_update
    asset_file.content_type = params[:content_type] if params[:content_type].present?
    render json: make_session
  end

  #: () -> void
  private def set_conference
    @conference = current_conference #: Conference?
  end

  #: () -> void
  private def set_asset_file
    @asset_file = SponsorEventAssetFile.find_by!(id: params[:id], sponsorship: current_sponsorship) #: SponsorEventAssetFile?
  end

  #: () -> void
  private def require_accepted_sponsorship
    unless current_sponsorship.accepted?
      render status: :forbidden, json: {error: 'sponsorship_not_accepted'}
    end
  end

  #: (AssetFileSessionable::asset_file_record) -> String
  private def asset_file_report_to_url(asset_file)
    user_conference_event_asset_file_path(conference, asset_file)
  end

  #: () -> Conference
  private def conference = Must.because(@conference) { "set_conference runs before every action" }

  #: () -> SponsorEventAssetFile
  private def asset_file = Must.because(@asset_file) { "set_asset_file or create assigns @asset_file" }
end
