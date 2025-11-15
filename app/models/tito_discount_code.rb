class TitoDiscountCode < ApplicationRecord
  belongs_to :sponsorship

  enum :kind, %i(attendee booth_staff booth_paid)

  def url
    "https://ti.to/#{sponsorship.conference.tito_slug}/discount/#{code}"
  end

  def dashboard_orders_url
    "https://dashboard.tito.io/#{sponsorship.conference.tito_slug}/registrations/?search%5Bq%5D=#{code}"
  end
end
