# typed: strict
# frozen_string_literal: true

module Api
  # Publishes a stored Rk::SponsorApp::Internal::FallbackOption.
  class FallbackOptionResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::FallbackOption do
      attributes :value, :name
      many :conditions, resource: Api::FallbackOptionConditionResource
      attribute(:priority_human) { |option| option.priority_human.to_a }
    end
  end
end
