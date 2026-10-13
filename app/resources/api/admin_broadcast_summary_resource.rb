# typed: strict
# frozen_string_literal: true

module Api
  class AdminBroadcastSummaryResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::AdminBroadcastSummary do
      attributes :id, :campaign, :title
      attribute(:status) { |broadcast| :"STATUS_#{broadcast.status.upcase}" }
      attributes dispatched_at: :timestamp, if: proc { |broadcast| broadcast.dispatched_at }
    end
  end
end
