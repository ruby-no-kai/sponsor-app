# typed: strict
# frozen_string_literal: true

module SponsorsFile
  # Binds the sponsorships showing one plan name, in sponsorship order.
  class PlanResource < ApplicationResource
    with_protobuf Rk::SponsorApp::SponsorsFile::Plan do
      attribute(:plan_name) { |plan| plan.sponsors.fetch(0).plan_name }
      many :sponsors, resource: SponsorResource
    end

    # BasePlan.plans for sponsorships with presence, in sponsorship order.
    #: (Array[Sponsorship]) -> Hash[String, Hash[Symbol, untyped]]
    def self.mapping(sponsorships)
      sponsorships
        .group_by { key_of(Must.because(it.plan_name) { "the sponsors file lists sponsorships with presence, which have a plan" }) }
        .transform_values { new(Group.new(sponsors: it)).to_h }
    end
  end
end
