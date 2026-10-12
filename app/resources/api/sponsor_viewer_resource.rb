# typed: strict
# frozen_string_literal: true

module Api
  class SponsorViewerResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::SponsorViewer do
      attributes :staff, :locale
      attributes :email, if: proc { |viewer| viewer.email }
      many :sponsorships, resource: Api::SponsorViewerSponsorshipResource
    end
  end
end
