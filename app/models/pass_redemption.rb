# typed: strict
# frozen_string_literal: true

# Controls Tito registrations and tickets thru source attributed to a sponsorship, for self managed pass management.
class PassRedemption
  class PaginationNotSupported < StandardError; end

  Registration = Data.define(
    :id, :slug, :reference,
    :discount_code, :source,
    :email,
    :state,
    :free, :paid, :cancelled, :refunded, :partially_refunded,
    :tickets
  ) do
    # Reads Tito's API response (Symbol keys) or a copy stored in a json column (String keys).
    # Absent keys read as nil, since Tito owns the shape.
    #: (Hash[untyped, untyped], releases: Hash[String, TitoCachedRelease]) -> Registration
    def self.from_tito(tito_registration, releases:)
      tito = tito_registration.deep_symbolize_keys #: Hash[Symbol, untyped]
      new(
        id: tito[:id],
        slug: tito[:slug],
        reference: tito[:reference],
        discount_code: tito[:discount_code],
        source: tito[:source],
        email: tito[:email],
        state: tito[:state],
        free: tito[:free],
        paid: tito[:paid],
        cancelled: tito[:cancelled],
        refunded: tito[:refunded],
        partially_refunded: tito[:partially_refunded],
        tickets: tito.fetch(:tickets, []).map { |t| Ticket.from_tito(t, releases:) },
      )
    end
  end

  Ticket = Data.define(
    :id, :reference,
    :discount_code, :release_id, :release_slug,
    :email,
    :state,
    :void, :assigned
  ) do
    #: (Hash[Symbol, untyped], releases: Hash[String, TitoCachedRelease]) -> Ticket
    def self.from_tito(tito_ticket, releases:)
      release_id = tito_ticket[:release_id].to_s
      new(
        id: tito_ticket[:id],
        reference: tito_ticket[:reference],
        discount_code: tito_ticket[:discount_code_used],
        release_id:,
        release_slug: releases[release_id]&.tito_release_slug,
        email: tito_ticket[:email],
        state: tito_ticket[:state],
        void: tito_ticket[:void],
        assigned: tito_ticket[:assigned],
      )
    end
  end

  class Collection
    #: (TitoApi::json_object, ?sponsorship: Sponsorship?, ?conference: Conference?) -> Collection
    def self.from_tito_registration_list(tito_registration_list, sponsorship: nil, conference: sponsorship&.conference)
      if (tito_registration_list.dig(:meta, :total_pages) || 0) > 1
        raise PaginationNotSupported
      end

      releases = conference ? TitoCachedRelease.where(conference:).index_by(&:tito_release_id) : {}
      valid_discount_codes = sponsorship&.tito_discount_codes&.pluck(:code) #: Array[String]?

      registrations = tito_registration_list.fetch(:registrations).map do |tito_registration|
        Registration.from_tito(tito_registration, releases:)
      end
      if valid_discount_codes
        registrations = registrations.select { |reg| valid_discount_codes.include?(reg.discount_code) }
      end

      new(registrations:, valid_discount_codes:)
    end

    # A nil valid_discount_codes shows every ticket.
    #: (registrations: Array[Registration], valid_discount_codes: Array[String]?) -> void
    def initialize(registrations:, valid_discount_codes:)
      @registrations = registrations
      @valid_discount_codes = valid_discount_codes
    end

    #: Array[Registration]
    attr_reader :registrations

    #: Array[String]?
    attr_reader :valid_discount_codes

    #: (Registration) -> Array[Ticket]
    def tickets_for(registration)
      codes = valid_discount_codes or return registration.tickets
      registration.tickets.select { |ticket| codes.include?(ticket.discount_code) }
    end

    # Whether the registration holds tickets claimed with codes other than the sponsorship's.
    #: (Registration) -> bool
    def holds_other_codes?(registration)
      tickets_for(registration).size < registration.tickets.size
    end

    # Judges the shown tickets only. TitoTicketRetraction checks every ticket.
    #: (Registration) -> bool
    def retractable?(registration)
      TitoTicketRetraction::Preconditions.from_registration(
        registration.with(tickets: tickets_for(registration)),
        valid_discount_codes: valid_discount_codes || [],
      ).satisfied?
    end
  end

  #: (Sponsorship) -> Collection
  def self.list_for_sponsorship(sponsorship)
    conference = Must.expect(sponsorship.conference)
    # Raises RecordNotFound until the sponsorship's source exists on Tito.
    TitoSource.find_by!(sponsorship:, conference:)
    tito_slug = Must.because(conference.tito_slug) { "PassRedemptionsController requires a tito_slug" }
    list_for_source_id(tito_slug, sponsorship.tito_source_code, sponsorship:)
  rescue PaginationNotSupported
    raise PaginationNotSupported, "Pagination not supported, encountered for #{sponsorship.name.inspect} on event=#{Must.expect(sponsorship.conference).slug.inspect}"
  end

  #: (String, String, ?sponsorship: Sponsorship?) -> Collection
  def self.list_for_source_id(tito_event, source, sponsorship: nil)
    Collection.from_tito_registration_list(
      TitoApi.new.list_registrations(
        tito_event,
        'expand' => 'tickets',
        'search[source]' => source,
        'search[states]' => %w(paid unpaid complete confirmed incomplete cancelled),
        'page[size]' => '1000',
      ),
      sponsorship:,
    )
  rescue PaginationNotSupported
    raise PaginationNotSupported, "Pagination not supported, encountered for source=#{source.inspect} on event=#{tito_event.inspect}"
  end
end
