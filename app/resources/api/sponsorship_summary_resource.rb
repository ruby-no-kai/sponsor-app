# typed: strict
# frozen_string_literal: true

module Api
  class SponsorshipSummaryResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::SponsorshipSummary do
      attributes :id, :name, :booth_assigned, :suspended
      attributes :customization_name, if: proc { |sponsorship| sponsorship.customization_name.present? }
      attributes :plan_id, if: proc { |sponsorship| sponsorship.plan_id }
      one :organization, resource: Api::OrganizationSummaryResource

      attribute(:state) { |sponsorship| Api::SponsorshipSummaryResource.state_of(sponsorship) }
      attribute(:customization_planned, &:customization_planned?)
    end

    # The SponsorshipState value of the sponsorship.
    #: (Sponsorship) -> Symbol
    def self.state_of(sponsorship)
      case
      when sponsorship.withdrawn? then :SPONSORSHIP_STATE_WITHDRAWN
      when sponsorship.accepted? then :SPONSORSHIP_STATE_ACTIVE
      else :SPONSORSHIP_STATE_PENDING
      end
    end
  end
end
