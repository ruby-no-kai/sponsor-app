# typed: strict
# frozen_string_literal: true

module Api
  # Load sponsorships with their conference, plan and organization, or each one queries them itself.
  class OrganizationSponsorshipResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::OrganizationSponsorship do
      one :sponsorship, source: proc { self }, resource: Api::SponsorshipSummaryResource
      one :conference, resource: Api::ConferenceResource
      attributes :booth_requested
      attribute(:plan_name, if: proc { |sponsorship| sponsorship.plan }) { |sponsorship| sponsorship.plan.name }
    end
  end
end
