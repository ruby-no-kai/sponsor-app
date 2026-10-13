# typed: strict
# frozen_string_literal: true

module Api
  class SponsorshipAssetFileResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::SponsorshipAssetFile do
      attributes :id
      attribute(:extension) { |asset_file| asset_file.extension.presence || 'unknown' }
    end
  end
end
