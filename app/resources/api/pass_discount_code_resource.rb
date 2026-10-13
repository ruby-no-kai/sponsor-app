# typed: strict
# frozen_string_literal: true

module Api
  # Quantities are as last synced to Tito, not the sponsorship's current terms.
  class PassDiscountCodeResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::PassDiscountCode do
      attribute(:kind) { |discount_code| :"KIND_#{discount_code.kind.upcase}" }
      attributes :url
      attributes :quantity, if: proc { |discount_code| !discount_code.booth_paid? }
    end
  end
end
