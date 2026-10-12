# typed: strict
# frozen_string_literal: true

module Api
  class AdminSponsorshipPlanResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::AdminSponsorship::Plan do
      attributes :id, :name, :rank, :number_of_guests
      attribute(:price_text) { |plan| plan.price_text.to_s }
      attribute(:booth_size) { |plan| plan.booth_size || 0 }
      attribute(:talkable) { |plan| !!plan.talkable }
      attribute(:words_limit) { |plan| plan.words_limit || 0 }
      attribute(:words_limit_hard) { |plan| plan.words_limit_hard.to_i }
    end
  end
end
