# typed: strict
# frozen_string_literal: true

module Api
  # Quantities are the sponsorship's current terms, not the copy last synced to the ticketing service.
  class TitoDiscountCodeResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::TitoDiscountCode do
      attribute(:kind) { |discount_code| :"KIND_#{discount_code.kind.upcase}" }
      attributes :url
      attribute(:quantity, if: proc { |discount_code| Api::TitoDiscountCodeResource.quantity_of(discount_code) }) do |discount_code|
        Api::TitoDiscountCodeResource.quantity_of(discount_code)
      end
    end

    # Tickets the sponsorship includes for the code's kind, or nil for paid booth passes.
    #: (::TitoDiscountCode) -> Integer?
    def self.quantity_of(discount_code)
      sponsorship = Must.expect(discount_code.sponsorship)
      case discount_code.kind
      when 'attendee' then sponsorship.total_number_of_attendees
      when 'booth_staff' then sponsorship.total_number_of_booth_staff
      end
    end
  end
end
