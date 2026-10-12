# typed: strict
# frozen_string_literal: true

module Api
  class SponsorViewerSponsorshipResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::SponsorViewer::Sponsorship do
      attributes :id, :name
      one :conference, resource: Api::ConferenceResource
    end
  end
end
