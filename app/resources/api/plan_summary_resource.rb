# typed: strict
# frozen_string_literal: true

module Api
  # Load plans with Plan.with_active_sponsorship_count, or each one counts its sponsorships itself.
  class PlanSummaryResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::PlanSummary do
      attributes :id, :name, :rank, :capacity, :active_sponsorship_count
    end
  end
end
