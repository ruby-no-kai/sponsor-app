class TitoDiscountCode < ApplicationRecord
  belongs_to :sponsorship

  enum kind: %i(attendee booth_staff)

  def url
    "https://ti.to/#{sponsorship.conference.tito_slug}/discount/#{code}"
  end
end
