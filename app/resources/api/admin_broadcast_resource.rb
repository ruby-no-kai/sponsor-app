# typed: strict
# frozen_string_literal: true

module Api
  class AdminBroadcastResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::AdminBroadcast do
      attributes :id, :campaign, :description, :title, :body
      attribute(:body_html) { |broadcast| broadcast.html.to_str }
      attribute(:status) { |broadcast| :"STATUS_#{broadcast.status.upcase}" }
      attributes dispatched_at: :timestamp, if: proc { |broadcast| broadcast.dispatched_at }
      attribute(:content_locked, &:content_locked?)
    end
  end
end
