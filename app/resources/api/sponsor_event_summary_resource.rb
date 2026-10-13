# typed: strict
# frozen_string_literal: true

module Api
  class SponsorEventSummaryResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::SponsorEventSummary do
      attributes :id, :title
      attributes starts_at: :timestamp
      attribute(:status) { |event| :"SPONSOR_EVENT_STATUS_#{event.status.upcase}" }
    end
  end
end
