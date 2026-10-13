# typed: strict
# frozen_string_literal: true

module Api
  # Binds the presigned POST that AssetFileUploadable#make_session returns.
  class AssetUploadResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::AssetUpload do
      attributes :url, :fields, :max_size
      attribute(:file_id) { |session| Integer(session.fetch(:id)) }
    end
  end
end
