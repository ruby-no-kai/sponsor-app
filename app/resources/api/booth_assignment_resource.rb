# typed: strict
# frozen_string_literal: true

module Api
  class BoothAssignmentResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::BoothAssignment do
      attributes :candidate_count, :candidate_booth_size, :requesting_count, :assigned_count, :assigned_booth_size
      many :candidates, resource: Api::BoothAssignmentCandidateResource
    end
  end
end
