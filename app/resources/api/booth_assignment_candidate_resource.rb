# typed: strict
# frozen_string_literal: true

module Api
  # Load sponsorships with their plan and organization, or each one queries them itself.
  class BoothAssignmentCandidateResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::BoothAssignmentCandidate do
      one :sponsorship, source: proc { self }, resource: Api::SponsorshipSummaryResource
      attributes :booth_requested
      attribute(:plan_name, if: proc { |sponsorship| sponsorship.plan }) { |sponsorship| sponsorship.plan.name }
      attribute(:booth_size) { |sponsorship| sponsorship.booth_size || 0 }
    end
  end
end
