# typed: strict
# frozen_string_literal: true

module Api
  # Load sponsorships with their plan, or each one queries it itself.
  class SponsorshipResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::Sponsorship do
      attributes :id, :name, :url, :profile, :locale, :booth_requested, :booth_assigned
      attribute(:state) { |sponsorship| Api::SponsorshipSummaryResource.state_of(sponsorship) }
      attribute(:plan_name, if: proc { |sponsorship| sponsorship.plan }) { |sponsorship| sponsorship.plan&.name.to_s }

      # A package that is named but not confirmed is the organizers' plan, not yet the sponsor's.
      attribute(:customized, &:customized?)
      attributes :customization_name, if: proc { |sponsorship| sponsorship.customized? }

      attribute(:sponsor_talk) do |sponsorship|
        !!sponsorship.plan&.talkable? && !sponsorship.customized? && !sponsorship.customization_planned?
      end
      attribute(:booth_eligible) { |sponsorship| !!sponsorship.plan&.booth_eligible? }
    end
  end
end
