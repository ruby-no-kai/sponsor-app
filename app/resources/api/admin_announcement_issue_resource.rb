# typed: strict
# frozen_string_literal: true

module Api
  class AdminAnnouncementIssueResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::AdminAnnouncementIssue do
      attributes :issue
      attribute(:announcements) do |issue|
        issue.announcements.map do |announcement|
          Api::AdminAnnouncementSummaryResource.new(announcement, params: {latest_revision: issue.latest_revision}).as_protobuf
        end
      end
    end
  end
end
