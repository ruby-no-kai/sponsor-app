# typed: strict
# frozen_string_literal: true

class TitoTicketRetraction < ApplicationRecord
  belongs_to :conference
  belongs_to :sponsorship

  validates :reason, presence: true
  validates :tito_registration, presence: true
  validates :tito_registration_id, presence: true

  validate :validate_retractable, on: :create

  Preconditions = Data.define(
    :free, :paid, :refunded, :partially_refunded, :cancelled,
    :ticket_release_count, :ticket_discount_code_count,
    :discount_codes_used, :invalid_discount_codes, :valid_discount_code_used
  ) do
    #: (PassRedemption::Registration, valid_discount_codes: Array[String]) -> Preconditions
    def self.from_registration(registration, valid_discount_codes:)
      tickets = registration.tickets
      discount_codes_used = tickets.map(&:discount_code).uniq
      new(
        free: registration.free,
        paid: registration.paid,
        refunded: registration.refunded,
        partially_refunded: registration.partially_refunded,
        cancelled: registration.cancelled,
        ticket_release_count: tickets.map(&:release_id).uniq.size,
        ticket_discount_code_count: discount_codes_used.size,
        discount_codes_used:,
        invalid_discount_codes: discount_codes_used - valid_discount_codes,
        valid_discount_code_used: tickets.all? { |t| valid_discount_codes.include?(t.discount_code) },
      )
    end

    # A flag missing from Tito's response refuses the retraction.
    #: () -> bool
    def satisfied?
      free == true &&
        paid == false &&
        refunded == false &&
        partially_refunded == false &&
        cancelled == false &&
        ticket_release_count == 1 &&
        ticket_discount_code_count == 1 &&
        valid_discount_code_used
    end
  end

  #: (Sponsorship, String) -> TitoTicketRetraction
  def self.prepare(sponsorship, tito_registration_id)
    new(
      sponsorship:,
      conference: sponsorship.conference,
      tito_registration_id: tito_registration_id.to_s,
      completed: false,
    ).tap(&:refresh_tito_registration)
  end

  #: (?api: TitoApi) -> self
  def refresh_tito_registration(api: TitoApi.new)
    tito_slug = Must.because(Must.expect(Must.expect(sponsorship).conference).tito_slug) { "retractions are only made on conferences with a tito_slug" }
    self.tito_registration = api.get_registration(tito_slug, tito_registration_id, 'expand' => 'tickets').fetch(:registration)
    self
  end

  # Built on each call, as refresh_tito_registration and restore_tito_registration! replace the column.
  #: () -> PassRedemption::Registration?
  def registration_maybe
    raw = tito_registration or return
    releases = conference ? TitoCachedRelease.where(conference:).index_by(&:tito_release_id) : {}
    PassRedemption::Registration.from_tito(raw, releases:)
  end

  #: () -> PassRedemption::Registration
  def registration = Must.because(registration_maybe) { "tito_registration is validated present and set by refresh_tito_registration" }

  #: () -> Preconditions?
  def preconditions
    reg = registration_maybe or return
    valid_discount_codes = sponsorship&.tito_discount_codes&.pluck(:code) || [] #: Array[String]
    Preconditions.from_registration(reg, valid_discount_codes:)
  end

  #: () -> bool
  def retractable?
    preconds = preconditions or return false
    preconds.satisfied?
  end

  # Whether the registration was made under the sponsorship's Tito source, with its discount codes
  # for the registration and every ticket. Tito also finds a registration by its slug, which the ID
  # check rules out.
  #: () -> bool
  def registered_through_sponsorship?
    registration = registration_maybe or return false
    sponsorship = Must.expect(self.sponsorship)
    codes = sponsorship.tito_discount_codes.pluck(:code)

    return false unless registration.id.to_s == tito_registration_id
    return false unless registration.source == sponsorship.tito_source_code
    return false unless codes.include?(registration.discount_code)

    registration.tickets.all? { |ticket| codes.include?(ticket.discount_code) }
  end

  #: () -> String?
  def order_reference
    registration_maybe&.reference
  end

  #: () -> String?
  def registration_email
    registration_maybe&.email
  end

  #: () -> String
  def tito_admin_url
    "https://dashboard.tito.io/#{Must.expect(conference).tito_slug}/registrations/#{URI.encode_www_form_component(registration_maybe&.slug)}"
  end

  #: () -> Array[String?]?
  def ticket_release_slugs
    registration_maybe&.tickets&.map(&:release_slug)&.uniq
  end

  # Every ticket of the stored registration, all of which the retraction voids.
  #: () -> Array[PassRedemption::Ticket]
  def affected_tickets
    registration_maybe&.tickets || []
  end

  #: () -> void
  private def validate_retractable
    unless retractable?
      errors.add(:tito_registration, :unable_to_retract)
    end
  end
end
