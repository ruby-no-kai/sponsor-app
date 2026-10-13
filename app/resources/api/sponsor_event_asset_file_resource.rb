# typed: strict
# frozen_string_literal: true

module Api
  class SponsorEventAssetFileResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::SponsorEventAssetFile do
      attributes :id
      attribute(:extension) { |asset_file| asset_file.extension.presence || 'unknown' }
    end
  end
end
