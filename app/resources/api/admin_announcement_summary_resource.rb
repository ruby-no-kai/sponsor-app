# typed: strict
# frozen_string_literal: true

module Api
  # Takes the latest revision of the announcement's issue in `params[:latest_revision]`.
  class AdminAnnouncementSummaryResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::AdminAnnouncementSummary do
      attributes :locale, :title, :exhibitors_only, :revision
      attribute(:published, &:published?)
      attribute(:pinned, &:pin?)
      attribute(:behind) { |announcement| announcement.revision < params.fetch(:latest_revision) }
    end
  end
end
