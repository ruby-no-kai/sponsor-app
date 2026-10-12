# typed: strict
# frozen_string_literal: true

module Api
  class OrganizationSummaryResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::OrganizationSummary do
      attributes :domain, :name
    end
  end
end
