# typed: strict
# frozen_string_literal: true

module Api
  # Takes the sponsor page URL in `params[:sponsor_page_url]`, as it is built from the request's host.
  class AdminAnnouncementResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::AdminAnnouncement do
      attributes :issue, :locale, :title, :body, :exhibitors_only, :revision
      attribute(:body_html) { |announcement| announcement.html.to_str }
      attribute(:published, &:published?)
      attributes published_at: :timestamp, if: proc { |announcement| announcement.published_at }
      attribute(:pinned, &:pin?)
      attribute(:sponsor_page_url) { params.fetch(:sponsor_page_url) }
    end
  end
end
