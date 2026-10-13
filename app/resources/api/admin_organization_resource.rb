# typed: strict
# frozen_string_literal: true

module Api
  # Load organizations with Organization.with_sponsorship_count, or each one counts its sponsorships
  # itself.
  class AdminOrganizationResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::AdminOrganization do
      attributes :domain, :name, :auto_acceptance_disabled, :affiliation_code, :sponsorship_count
    end
  end
end
