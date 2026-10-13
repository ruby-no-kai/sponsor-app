# typed: strict
# frozen_string_literal: true

module Api
  # Load plans with Plan.with_active_sponsorship_count, or each one counts its sponsorships itself.
  class ApplicationPlanResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::ApplicationPlan do
      attributes :id, :name, :number_of_guests, :auto_acceptance

      # Nullable columns the message holds as plain scalars publish null as empty, zero or false.
      attribute(:price_text) { |plan| plan.price_text.to_s }
      attribute(:booth_size) { |plan| plan.booth_size.to_i }
      attribute(:words_limit) { |plan| plan.words_limit.to_i }
      attribute(:talkable, &:talkable?)

      attribute(:booth_eligible, &:booth_eligible?)
      attribute(:sold_out, &:sold_out?)
      attribute(:closed, &:closed?)
      attribute(:available, &:available?)
    end
  end
end
