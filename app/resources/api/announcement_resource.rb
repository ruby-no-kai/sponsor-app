# typed: strict
# frozen_string_literal: true

module Api
  class AnnouncementResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::Announcement do
      attributes :issue, :title
      attribute(:body_html) { |announcement| announcement.html.to_str }
      attributes published_at: :timestamp
    end
  end
end
