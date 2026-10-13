# typed: strict
# frozen_string_literal: true

# Builds the BroadcastRecipientFilter that CreateBroadcastDeliveriesJob takes from the admin
# recipient filter form.
class BroadcastRecipientFilterParams
  INT64_RANGE = -9_223_372_036_854_775_808..9_223_372_036_854_775_807 #: Range[Integer]

  # Returns nil for the kind "none".
  #: (ActionController::Parameters) -> Rk::SponsorApp::Internal::BroadcastRecipientFilter?
  def self.build(params)
    permitted = params.permit(
      :kind,
      :locale,
      :exhibitors,
      :plan_id,
      :status,
      :id,
      :exclude_current_sponsors,
      :emails,
      sponsorship_ids: [],
    )
    new(permitted).filter
  end

  # Reads a CreateBroadcastDeliveriesJob argument enqueued as the Hash of permitted form params.
  #: (Hash[String, untyped]) -> Rk::SponsorApp::Internal::BroadcastRecipientFilter?
  def self.from_legacy_hash(hash)
    build(ActionController::Parameters.new(hash))
  end

  #: (ActionController::Parameters) -> void
  def initialize(params)
    @params = params
  end

  #: () -> Rk::SponsorApp::Internal::BroadcastRecipientFilter?
  def filter
    kind = @params[:kind]
    case kind
    when 'none'
      nil
    when 'all'
      Rk::SponsorApp::Internal::BroadcastRecipientFilter.new(current_sponsors:)
    when 'past_sponsors'
      Rk::SponsorApp::Internal::BroadcastRecipientFilter.new(past_sponsors:)
    when 'manual'
      Rk::SponsorApp::Internal::BroadcastRecipientFilter.new(manual:)
    when 'raw'
      Rk::SponsorApp::Internal::BroadcastRecipientFilter.new(raw:)
    else
      raise ActionController::BadRequest, "unknown recipient filter kind: #{kind.inspect}"
    end
  end

  #: () -> Rk::SponsorApp::Internal::BroadcastRecipientFilter::CurrentSponsors
  private def current_sponsors
    Rk::SponsorApp::Internal::BroadcastRecipientFilter::CurrentSponsors.new(
      locale: string_param(:locale),
      exhibitors_only: @params[:exhibitors].present?,
      plan_id: (parse_id(@params[:plan_id]) if @params[:plan_id].present?),
      status:,
    )
  end

  #: () -> Rk::SponsorApp::Internal::BroadcastRecipientFilter::PastSponsors
  private def past_sponsors
    Rk::SponsorApp::Internal::BroadcastRecipientFilter::PastSponsors.new(
      conference_id: parse_id(@params[:id]),
      locale: string_param(:locale),
      exclude_current_sponsors: @params[:exclude_current_sponsors].present?,
      status:,
    )
  end

  #: () -> Rk::SponsorApp::Internal::BroadcastRecipientFilter::Manual
  private def manual
    Rk::SponsorApp::Internal::BroadcastRecipientFilter::Manual.new(
      sponsorship_ids: Array(@params[:sponsorship_ids]).map { parse_id(it) },
    )
  end

  #: () -> Rk::SponsorApp::Internal::BroadcastRecipientFilter::Raw
  private def raw
    Rk::SponsorApp::Internal::BroadcastRecipientFilter::Raw.new(
      emails: @params[:emails].to_s.each_line.map(&:chomp),
    )
  end

  #: () -> Symbol
  private def status
    value = @params[:status]
    case value
    when 'all', nil then :SPONSORSHIP_STATUS_UNSPECIFIED
    when 'pending' then :SPONSORSHIP_STATUS_PENDING
    when 'active' then :SPONSORSHIP_STATUS_ACTIVE
    when 'not_accepted' then :SPONSORSHIP_STATUS_NOT_ACCEPTED
    when 'accepted' then :SPONSORSHIP_STATUS_ACCEPTED
    when 'withdrawn' then :SPONSORSHIP_STATUS_WITHDRAWN
    else raise ActionController::BadRequest, "unknown sponsorship status: #{value.inspect}"
    end
  end

  #: (untyped) -> Integer
  private def parse_id(value)
    id = Integer(value.to_s, 10)
    raise ActionController::BadRequest, "id out of int64 range: #{value.inspect}" unless INT64_RANGE.cover?(id)

    id
  rescue ArgumentError
    raise ActionController::BadRequest, "invalid id: #{value.inspect}"
  end

  #: (Symbol) -> String?
  private def string_param(key)
    value = @params[key]
    case value
    when String then value.presence
    when nil then nil
    else raise ActionController::BadRequest, "invalid #{key}: #{value.inspect}"
    end
  end
end
