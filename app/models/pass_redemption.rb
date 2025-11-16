# Controls Tito registrations and tickets thru source attributed to a sponsorship, for self managed pass management.
class PassRedemption
  class PaginationNotSupported < StandardError; end

  Registration = Data.define(
    :id, :reference,
    :discount_code, :source,
    :email,
    :state,
    :free, :paid, :cancelled, :refunded, :partially_refunded,
    :tickets,
  ) do
    def retractable?
      free && !paid && !refunded && !partially_refunded && tickets.tally { |t| t.release_id }.size == 1 && tickets.tally { |t| t.discount_code }.size == 1
    end

    def as_json
      to_h.merge(
        tickets: tickets.map(&:as_json),
        retractable: retractable?,
      )
    end
  end
  Ticket = Data.define(
    :id, :reference,
    :discount_code, :release, :release_id,
    :email,
    :state,
    :void, :assigned,
  ) do
    def as_json = to_h
  end

  class Collection
    def self.from_tito_registration_list(tito_registration_list, sponsorship: nil, conference: sponsorship&.conference)
      if (tito_registration_list.dig('meta','total_pages') || 0) > 1
        raise PaginationNotSupported
      end

      releases = conference ? TitoCachedRelease.where(conference:).map { |r| [r.tito_release_id, r] }.to_h : {}

      valid_discount_code = sponsorship&.tito_discount_codes&.pluck(:code)
      registrations = tito_registration_list.fetch(:registrations).map do |tito_registration|
        tickets = tito_registration.fetch(:tickets).map do |tito_ticket|
          Ticket.new(
            id: tito_ticket[:id],
            reference: tito_ticket[:reference],
            discount_code: tito_ticket[:discount_code_used],
            release: releases[tito_ticket[:release_id].to_s],
            release_id: tito_ticket[:release_id].to_s,
            email: tito_ticket[:email],
            state: tito_ticket[:state],
            void: tito_ticket[:void],
            assigned: tito_ticket[:assigned],
          )
        end.select do |ticket|
          !valid_discount_code || valid_discount_code.include?(ticket.discount_code)
        end

        Registration.new(
          id: tito_registration[:id],
          reference: tito_registration[:reference],
          source: tito_registration[:source],
          discount_code: tito_registration[:discount_code],
          email: tito_registration[:email],
          state: tito_registration[:state],
          free: tito_registration[:free],
          paid: tito_registration[:paid],
          cancelled: tito_registration[:cancelled],
          refunded: tito_registration[:refunded],
          partially_refunded: tito_registration[:partially_refunded],
          tickets: tickets,
        )
      end.select do |reg|
        !valid_discount_code || valid_discount_code.include?(reg.discount_code)
      end

      new(registrations:)
    end

    def initialize(registrations:)
      @registrations = registrations
    end

    attr_reader :registrations
  end

  def self.list_for_sponsorship(sponsorship)
    source = TitoSource.find_by!(sponsorship:, conference: sponsorship.conference)
    list_for_source_id(sponsorship.conference.tito_slug, source.tito_source_id, sponsorship:)
  rescue PaginationNotSupported
    raise PaginationNotSupported, "Pagination not supported, encountered for #{sponsorship.name.inspect} on event=#{sponsorship.conference.slug.inspect}"
  end

  def self.list_for_source_id(tito_event, source_id, sponsorship: nil)
    Collection.from_tito_registration_list(
      TitoApi.new.list_registrations(
        tito_event,
        'expand' => 'tickets',
        'search[source]' => source_id,
        'search[states]' => %w(paid unpaid complete confirmed incomplete cancelled),
      ),
      sponsorship:,
    )
  rescue PaginationNotSupported
    raise PaginationNotSupported, "Pagination not supported, encountered for source=#{source_id.inspect} on event=#{tito_event.inspect}"
  end
end
