# frozen_string_literal: true

class TitoDiscountCode < ApplicationRecord
  belongs_to :sponsorship

  enum :kind, {attendee: 0, booth_staff: 1, booth_paid: 2}

  def url
    "https://ti.to/#{sponsorship.conference.tito_slug}/discount/#{code}"
  end

  def dashboard_orders_url
    "https://dashboard.tito.io/#{sponsorship.conference.tito_slug}/registrations/?search%5Bq%5D=#{code}"
  end
end
