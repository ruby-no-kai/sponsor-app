# typed: strict
# frozen_string_literal: true

module Api
  # Load sponsorships with their plan, organization and requests, or each one queries them itself.
  class SponsorshipTableRowResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::SponsorshipTableRow do
      one :sponsorship, source: proc { self }, resource: Api::SponsorshipSummaryResource

      # Sponsorship#plan_name is the displayed name, which may be the custom package's.
      attribute(:plan_name, if: proc { |sponsorship| sponsorship.plan }) { |sponsorship| sponsorship.plan.name }
      attribute(:displayed_plan_name, if: proc { |sponsorship| sponsorship.plan_name }, &:plan_name)

      attribute(:billing_request, if: proc { |sponsorship| sponsorship.billing_request&.body.present? }) do |sponsorship|
        sponsorship.billing_request.body
      end
      attribute(:customization_request, if: proc { |sponsorship| sponsorship.customization_request&.body.present? }) do |sponsorship|
        sponsorship.customization_request.body
      end
      attribute(:note, if: proc { |sponsorship| sponsorship.note&.body.present? }) do |sponsorship|
        sponsorship.note.body
      end
    end
  end
end
