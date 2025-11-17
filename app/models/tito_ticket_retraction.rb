class TitoTicketRetraction < ApplicationRecord
  belongs_to :conference
  belongs_to :sponsorship

  validates :reason, presence: true
  validates :tito_registration, presence: true
  validates :tito_registration_id, presence: true

  validate :validate_retractable, on: :create

  # @param sponsorship [Sponsorship]
  # @param registration_id [String] Tito registration ID
  def self.prepare(sponsorship, tito_registration_id)
    new(
      sponsorship:,
      conference: sponsorship.conference,
      tito_registration_id: tito_registration_id.to_s,
      completed: false,
    ).tap do |r|
      r.refresh_tito_registration
    end
  end

  def refresh_tito_registration(api: TitoApi.new)
    self.tito_registration = api.get_registration(sponsorship.conference.tito_slug, tito_registration_id, 'expand' => 'tickets').fetch(:registration)
    self
  end

  def preconditions
    reg = tito_registration or return nil
    valid_discount_codes = sponsorship&.tito_discount_codes&.pluck(:code)
    discount_codes_used = reg.fetch('tickets').map { |t| t.fetch('discount_code_used') }.uniq
    {
      free: reg.fetch('free'),
      paid: reg.fetch('paid'),
      refunded: reg.fetch('refunded'),
      partially_refunded: reg.fetch('partially_refunded'),
      cancelled: reg.fetch('cancelled'),
      ticket_release_count: reg.fetch('tickets').group_by { |t| t.fetch('release_id') }.size,
      ticket_discount_code_count: reg.fetch('tickets').group_by { |t| t.fetch('discount_code_used') }.size,
      discount_codes_used:,
      invalid_discount_codes: discount_codes_used - valid_discount_codes,
      valid_discount_code_used: reg.fetch('tickets').all? { |t| valid_discount_codes&.include?(t.fetch('discount_code_used')) },
    }
  end

  def retractable?
    preconds = preconditions or return false
    preconds[:free] &&
      !preconds[:paid] &&
      !preconds[:refunded] &&
      !preconds[:partially_refunded] &&
      !preconds[:cancelled] &&
      preconds[:ticket_release_count] == 1 &&
      preconds[:ticket_discount_code_count] == 1 &&
      preconds[:valid_discount_code_used]
  end

  def order_reference
    tito_registration&.fetch('reference')
  end

  def tito_admin_url
    "https://dashboard.tito.io/#{conference.tito_slug}/registrations/#{URI.encode_www_form_component(tito_registration&.fetch('slug')&.to_s)}"
  end

  def ticket_release_slugs
    releases = conference ? TitoCachedRelease.where(conference:).map { |r| [r.tito_release_id, r] }.to_h : {}
    tito_registration&.fetch('tickets')&.map { |t| releases[t.fetch('release_id').to_s]&.tito_release_slug }&.uniq
  end

  private def validate_retractable
    unless retractable?
      errors.add(:tito_registration, :unable_to_retract)
    end
  end
end
