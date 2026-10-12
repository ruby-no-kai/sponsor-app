# typed: strict
# frozen_string_literal: true

class TitoDiscountCode < ApplicationRecord
  belongs_to :sponsorship

  enum :kind, {attendee: 0, booth_staff: 1, booth_paid: 2}

  #: () -> String
  def url
    "https://ti.to/#{Must.expect(Must.expect(sponsorship).conference).tito_slug}/discount/#{code}"
  end

  #: () -> String
  def dashboard_orders_url
    "https://dashboard.tito.io/#{Must.expect(Must.expect(sponsorship).conference).tito_slug}/registrations/?search%5Bq%5D=#{code}"
  end
end
