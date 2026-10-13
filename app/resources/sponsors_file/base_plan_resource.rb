# typed: strict
# frozen_string_literal: true

module SponsorsFile
  # Binds the sponsorships under one base plan, in sponsorship order.
  class BasePlanResource < ApplicationResource
    with_protobuf Rk::SponsorApp::SponsorsFile::BasePlan do
      attribute(:base_plan) { |base_plan| ApplicationResource.base_plan_of(base_plan.sponsors.fetch(0)) }
      attribute(:plans) { |base_plan| PlanResource.mapping(base_plan.sponsors) }
    end

    # SponsorsFile.base_plans for sponsorships with presence, in sponsorship order.
    #: (Array[Sponsorship]) -> Hash[String, Hash[Symbol, untyped]]
    def self.mapping(sponsorships)
      sponsorships.group_by { key_of(base_plan_of(it)) }.transform_values { new(Group.new(sponsors: it)).to_h }
    end
  end
end
