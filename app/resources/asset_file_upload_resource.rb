# typed: strict
# frozen_string_literal: true

require 'protobufable/alba_binding'

# Binds the presigned POST that AssetFileUploadable#make_session returns, with report_to given as a param.
class AssetFileUploadResource
  include Alba::Resource
  include Protobufable::AlbaBinding

  with_protobuf Rk::SponsorApp::AssetFileUpload do
    attributes :url, :fields, :max_size
    attribute(:file_id) { |session| session.fetch(:id) }
    attribute(:report_to) { params.fetch(:report_to) }
    attribute(:id) { |session| session.fetch(:id).to_s }
  end
end
