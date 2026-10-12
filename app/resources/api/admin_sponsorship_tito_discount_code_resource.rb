# typed: strict
# frozen_string_literal: true

module Api
  class AdminSponsorshipTitoDiscountCodeResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::AdminSponsorship::TitoDiscountCode do
      attributes :code
      attribute(:kind) { |discount_code| :"KIND_#{discount_code.kind.upcase}" }
      attribute(:registration_url, &:url)
      attribute(:dashboard_url, &:dashboard_orders_url)
    end
  end
end
