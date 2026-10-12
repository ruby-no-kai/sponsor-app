# typed: strict
# frozen_string_literal: true

module Api
  # Load plans with Plan.with_active_sponsorship_count, or each one counts its sponsorships itself.
  class AdminPlanResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::AdminPlan do
      attributes :id, :name, :rank, :capacity, :number_of_guests, :auto_acceptance, :active_sponsorship_count
      attributes :summary, if: proc { |plan| plan.summary.present? }
      attributes :booth_size, if: proc { |plan| plan.booth_size }
      attributes closes_at: :timestamp, if: proc { |plan| plan.closes_at }

      # Nullable columns the message holds as plain scalars publish null as empty, zero or false.
      attribute(:price_text) { |plan| plan.price_text.to_s }
      attribute(:words_limit) { |plan| plan.words_limit.to_i }
      attribute(:talkable, &:talkable?)

      attribute(:price) { |plan| plan.price.to_s }
      attribute(:price_booth) { |plan| plan.price_booth.to_s }

      attribute(:sold_out, &:sold_out?)
      attribute(:closed, &:closed?)
      attribute(:available, &:available?)
    end
  end
end
