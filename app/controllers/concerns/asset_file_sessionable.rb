require 'active_support/concern'

module AssetFileSessionable
  extend ActiveSupport::Concern

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

  private

  def make_session
    @asset_file.make_session.merge(
      report_to: asset_file_report_to_url(@asset_file)
    )
  end

  # Each controller must implement this method
  def asset_file_report_to_url(asset_file)
    raise NotImplementedError, "#{self.class} must implement #asset_file_report_to_url"
  end
end
