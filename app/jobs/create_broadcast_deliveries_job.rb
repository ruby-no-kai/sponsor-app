# typed: strict
# frozen_string_literal: true

class CreateBroadcastDeliveriesJob < ApplicationJob
  Recipient = Data.define(:sponsorship, :email, :email_ccs)

  module Filters
    class Base
      #: (broadcast: Broadcast) -> void
      def initialize(broadcast:)
        @broadcast = broadcast
      end

      #: Broadcast
      attr_reader :broadcast

      #: () -> Array[Recipient]
      def recipients
        raise NotImplementedError
      end

      #: (Symbol | Integer) -> Sponsorship::PrivateRelation
      private def status_scope(status)
        case status
        when :SPONSORSHIP_STATUS_UNSPECIFIED
          Sponsorship.all
        when :SPONSORSHIP_STATUS_NOT_ACCEPTED
          Sponsorship.not_accepted
        when :SPONSORSHIP_STATUS_PENDING
          Sponsorship.pending
        when :SPONSORSHIP_STATUS_ACCEPTED
          Sponsorship.accepted
        when :SPONSORSHIP_STATUS_ACTIVE
          Sponsorship.active
        when :SPONSORSHIP_STATUS_WITHDRAWN
          Sponsorship.withdrawn
        else
          raise ArgumentError, "unknown sponsorship status: #{status.inspect}"
        end
      end

      #: (String) -> Sponsorship::PrivateRelation
      private def locale_scope(locale)
        Sponsorship.where(locale:)
      end

      #: (Sponsorship::PrivateAssociationRelation, Array[Sponsorship::PrivateRelation?]) -> Sponsorship::PrivateAssociationRelation
      private def scope_sponsorships(scope, scopes)
        scopes.compact.inject(scope) { |r, i| r.merge(i) }
      end

      #: (Sponsorship::PrivateRelation | Sponsorship::PrivateAssociationRelation) -> Array[Recipient]
      private def sponsorships_to_recipients(scope)
        scope.map do |sponsorship|
          contact = Must.because(sponsorship.contact) { "sponsorships validate the presence of their contact" }
          Recipient.new(
            sponsorship: sponsorship,
            email: contact.email,
            email_ccs: contact.email_ccs,
          )
        end
      end
    end

    class CurrentSponsors < Base
      #: (broadcast: Broadcast, filter: Rk::SponsorApp::Internal::BroadcastRecipientFilter::CurrentSponsors) -> void
      def initialize(broadcast:, filter:)
        super(broadcast:)
        @filter = filter
      end

      #: Rk::SponsorApp::Internal::BroadcastRecipientFilter::CurrentSponsors
      attr_reader :filter

      #: () -> Array[Recipient]
      def recipients
        conference = Must.expect(broadcast.conference)
        scope = scope_sponsorships(conference.sponsorships.includes(:contact), [
          status_scope(filter.status),
          plan_scope(conference),
          (locale_scope(filter.locale) if filter.has_locale?),
          (Sponsorship.exhibitor if filter.exhibitors_only),
        ])
        sponsorships_to_recipients(scope)
      end

      #: (Conference) -> Sponsorship::PrivateRelation?
      private def plan_scope(conference)
        return unless filter.has_plan_id?

        plan = conference.plans.find_by(id: filter.plan_id)
        Sponsorship.where(plan:) if plan
      end
    end

    class PastSponsors < Base
      #: (broadcast: Broadcast, filter: Rk::SponsorApp::Internal::BroadcastRecipientFilter::PastSponsors) -> void
      def initialize(broadcast:, filter:)
        super(broadcast:)
        @filter = filter
      end

      #: Rk::SponsorApp::Internal::BroadcastRecipientFilter::PastSponsors
      attr_reader :filter

      # TODO: apply exclude_current_sponsors, which the form offers.
      #: () -> Array[Recipient]
      def recipients
        conference = Conference.find_by!(id: filter.conference_id)
        scope = scope_sponsorships(conference.sponsorships.includes(:contact), [
          status_scope(filter.status),
          (locale_scope(filter.locale) if filter.has_locale?),
        ])
        sponsorships_to_recipients(scope)
      end
    end

    class Manual < Base
      #: (broadcast: Broadcast, filter: Rk::SponsorApp::Internal::BroadcastRecipientFilter::Manual) -> void
      def initialize(broadcast:, filter:)
        super(broadcast:)
        @filter = filter
      end

      #: Rk::SponsorApp::Internal::BroadcastRecipientFilter::Manual
      attr_reader :filter

      #: () -> Array[Recipient]
      def recipients
        sponsorships_to_recipients(Sponsorship.where(id: filter.sponsorship_ids.to_a))
      end
    end

    class Raw < Base
      #: (broadcast: Broadcast, filter: Rk::SponsorApp::Internal::BroadcastRecipientFilter::Raw) -> void
      def initialize(broadcast:, filter:)
        super(broadcast:)
        @filter = filter
      end

      #: Rk::SponsorApp::Internal::BroadcastRecipientFilter::Raw
      attr_reader :filter

      #: () -> Array[Recipient]
      def recipients
        filter.emails.map do |email|
          Recipient.new(
            sponsorship: nil,
            email:,
            email_ccs: [],
          )
        end
      end
    end
  end

  #: (Broadcast, Array[Rk::SponsorApp::Internal::BroadcastRecipientFilter | Hash[String, untyped]]) -> void
  def perform(broadcast, recipient_filters)
    ApplicationRecord.transaction do
      @broadcast = broadcast #: Broadcast?
      broadcast.lock!

      case
      when broadcast.created?
        broadcast.update!(status: :preparing)
      when broadcast.ready?
        broadcast.update!(status: :modifying)
      when broadcast.modifying?
        broadcast.update!(status: :modifying)
      else
        raise "Invalid state for CreateBroadcastDeliveriesJob (broadcast_id=#{broadcast.id}, state=#{broadcast.status})"
      end

      existing_emails = broadcast.deliveries.pluck(:recipient).tally
      recipients = recipient_filters.flat_map do |argument|
        filter = recipient_filter(argument)
        filter ? filter_recipients(filter) : []
      end

      recipients.map do |recipient|
        next if existing_emails[recipient.email]

        broadcast.deliveries.create!(
          status: :ready,
          sponsorship: recipient.sponsorship,
          recipient: recipient.email,
          recipient_cc: recipient.email_ccs.join(','),
        )
      end

      broadcast.lock!(false)

      broadcast.status = :ready
      broadcast.save!
    end
  end

  # Queued jobs may still carry the permitted form params as a Hash.
  #: (Rk::SponsorApp::Internal::BroadcastRecipientFilter | Hash[String, untyped]) -> Rk::SponsorApp::Internal::BroadcastRecipientFilter?
  private def recipient_filter(argument)
    case argument
    when Hash
      BroadcastRecipientFilterParams.from_legacy_hash(argument)
    else
      argument
    end
  end

  #: (Rk::SponsorApp::Internal::BroadcastRecipientFilter) -> Array[Recipient]
  private def filter_recipients(filter)
    case filter.kind
    when :current_sponsors
      sub = Must.because(filter.current_sponsors) { "kind names the field that is set" }
      Filters::CurrentSponsors.new(broadcast:, filter: sub).recipients
    when :past_sponsors
      sub = Must.because(filter.past_sponsors) { "kind names the field that is set" }
      Filters::PastSponsors.new(broadcast:, filter: sub).recipients
    when :manual
      sub = Must.because(filter.manual) { "kind names the field that is set" }
      Filters::Manual.new(broadcast:, filter: sub).recipients
    when :raw
      sub = Must.because(filter.raw) { "kind names the field that is set" }
      Filters::Raw.new(broadcast:, filter: sub).recipients
    else
      raise ArgumentError, "unknown recipient filter kind: #{filter.kind.inspect}"
    end
  end

  #: () -> Broadcast
  private def broadcast = Must.because(@broadcast) { "perform sets the broadcast before filtering recipients" }
end
