# typed: true
# frozen_string_literal: true

require 'active_support/concern'

# @requires_ancestor: ApplicationController
module AssetFileSessionable
  extend ActiveSupport::Concern

  #: type asset_file_record = SponsorshipAssetFile | SponsorEventAssetFile | ExpenseFile

  #: () -> void
  def update
    asset_file.assign_attributes(params.permit(:version_id))
    asset_file.extension = params[:extension]&.then { _1.downcase.gsub(/[^a-z0-9]/, '') } || 'unknown'

    asset_file.update_object_header

    if asset_file.save
      render json: {ok: true}
    else
      render status: :unprocessable_content, json: {ok: false, messages: asset_file.errors.full_messages}
    end
  end

  #: () -> { url: String, fields: Hash[String, String], max_size: Integer, id: String, report_to: String }
  private def make_session
    asset_file.make_session.merge(
      report_to: asset_file_report_to_url(asset_file),
    )
  end

  #: () -> asset_file_record
  private def asset_file = Must.because(@asset_file) { "set_asset_file or create assigns @asset_file" }

  # Each controller must implement this method
  #: (asset_file_record) -> String
  private def asset_file_report_to_url(asset_file)
    raise NotImplementedError, "#{self.class} must implement #asset_file_report_to_url"
  end
end
