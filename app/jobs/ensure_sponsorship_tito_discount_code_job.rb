# typed: strict
# frozen_string_literal: true

class EnsureSponsorshipTitoDiscountCodeJob < ApplicationJob
  # The discount code body sent to Tito. Every member is sent, nil and false included.
  DiscountCodeAttributes = Data.define(
    :code, :type, :value,
    :only_show_attached, :reveal_secret, :block_registrations_if_not_applicable,
    :quantity, :release_ids, :source_id, :description_for_organizer
  )

  #: (Sponsorship, String, ?ignore_quantity: bool) -> void
  def perform(sponsorship, kind, ignore_quantity: false)
    return unless Rails.application.config.x.tito.token

    @kind = kind #: String?
    @sponsorship = sponsorship #: Sponsorship?
    conference = Must.expect(sponsorship.conference)
    @conference = conference #: Conference?
    return if conference.tito_slug.blank?

    discount_code = sponsorship.tito_discount_codes.where(kind: kind).first

    if discount_code
      return if discount_code.quantity == quantity && !ignore_quantity

      attrs = discount_code_attributes
      # Spelled out, as Sorbet cannot check a Hash splat against required keywords.
      tito.update_discount_code(
        tito_slug, discount_code.tito_discount_code_id,
        code: attrs.code, type: attrs.type, value: attrs.value,
        only_show_attached: attrs.only_show_attached,
        reveal_secret: attrs.reveal_secret,
        block_registrations_if_not_applicable: attrs.block_registrations_if_not_applicable,
        quantity: attrs.quantity,
        release_ids: attrs.release_ids,
        source_id: attrs.source_id,
        description_for_organizer: attrs.description_for_organizer,
      )
      discount_code.update!(quantity: quantity)
    else
      return if quantity < 1

      attrs = discount_code_attributes
      tito_discount_code = tito.create_discount_code(
        tito_slug,
        code: attrs.code, type: attrs.type, value: attrs.value,
        only_show_attached: attrs.only_show_attached,
        reveal_secret: attrs.reveal_secret,
        block_registrations_if_not_applicable: attrs.block_registrations_if_not_applicable,
        quantity: attrs.quantity,
        release_ids: attrs.release_ids,
        source_id: attrs.source_id,
        description_for_organizer: attrs.description_for_organizer,
      )
      TitoDiscountCode.create!(
        sponsorship: sponsorship,
        kind: kind,
        code: code,
        quantity: quantity,
        tito_discount_code_id: tito_discount_code.fetch(:discount_code).fetch(:id),
      )
    end
  end

  #: () -> String
  def code
    "#{code_prefix}_#{sponsorship.id}_#{sponsorship.ticket_key[0, 12]}"
  end

  #: () -> DiscountCodeAttributes
  def discount_code_attributes
    attrs = DiscountCodeAttributes.new(
      code: code,
      type: 'PercentOffDiscountCode',
      value: '100.0',
      only_show_attached: true,
      reveal_secret: true,
      block_registrations_if_not_applicable: kind != 'attendee',
      quantity: quantity,
      release_ids: quantity > 0 ? release_ids : nil,
      source_id: tito_source.tito_source_id,
      description_for_organizer: "sponsorship=#{sponsorship.id}, domain=#{sponsorship.organization&.domain}, plan=#{sponsorship.plan&.name}",
    )
    return attrs unless kind == 'booth_paid'

    attrs.with(
      type: 'MoneyOffDiscountCode',
      value: conference.tito_booth_paid_flat_discount_amount.to_s,
    )
  end

  #: () -> Integer
  def quantity
    {
      'attendee' => sponsorship.total_number_of_attendees,
      'booth_staff' => sponsorship.total_number_of_booth_staff,
      'booth_paid' => sponsorship.total_number_of_booth_staff > 0 ? 6 : 0,
    }.fetch(kind)
  end

  #: () -> String
  def code_prefix
    {
      'attendee' => 'sa',
      'booth_staff' => 'sb',
      'booth_paid' => 'se',
    }.fetch(kind)
  end

  #: () -> Array[String]
  def release_slugs
    {
      'attendee' => %w(sponsor),
      'booth_staff' => %w(exhibitor),
      'booth_paid' => %w(exhibitor-paid),
    }.fetch(kind)
  end

  #: () -> TitoSource
  def tito_source
    @tito_source ||= sponsorship.tito_source || begin
      source = tito.create_source(
        tito_slug,
        code: sponsorship.tito_source_code,
        name: "Sponsor: #{sponsorship.name} (#{sponsorship.id})",
        description: "Sponsor: #{Must.expect(sponsorship.organization).name}, Conference: #{conference.name} (#{conference.id})",
      ).fetch(:source).fetch(:id)
      TitoSource.create!(
        conference: conference,
        sponsorship: sponsorship,
        tito_source_id: source.to_s,
      )
    end #: TitoSource?
  end

  #: () -> Array[String]
  def release_ids
    @release_ids ||= TitoCachedRelease.transaction do
      release_slugs.map do |slug|
        TitoCachedRelease.where(conference: conference, tito_release_slug: slug).first&.tito_release_id or begin
          id = tito.get_release(tito_slug, slug).fetch(:release).fetch(:id)
          TitoCachedRelease.create!(
            conference: conference,
            tito_release_slug: slug,
            tito_release_id: id.to_s,
          ).tito_release_id
        end
      end
    end #: Array[String]?
  end

  #: () -> TitoApi
  def tito
    @tito ||= TitoApi.new #: TitoApi?
  end

  #: () -> String
  private def kind = Must.because(@kind) { "perform sets the kind" }

  #: () -> Sponsorship
  private def sponsorship = Must.because(@sponsorship) { "perform sets the sponsorship" }

  #: () -> Conference
  private def conference = Must.because(@conference) { "perform sets the conference" }

  #: () -> String
  private def tito_slug = Must.because(conference.tito_slug) { "perform returns early for a conference without a tito_slug" }
end
