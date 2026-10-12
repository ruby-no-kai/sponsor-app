# typed: strict
# frozen_string_literal: true

module Api
  # Publishes a stored Rk::SponsorApp::Internal::FallbackOption::Condition.
  class FallbackOptionConditionResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::FallbackOption::Condition do
      attribute(:plans) { |condition| condition.plans.to_a }
      attributes :booth_request, if: proc { |condition| condition.has_booth_request? }
    end
  end
end
