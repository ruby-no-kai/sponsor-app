# typed: strict
# frozen_string_literal: true

module Api
  # Takes the conference's sponsorships the event names as co-hosts in `params[:co_hosts]`, by ID,
  # so that one query loads them for every event listed. Load events with their sponsorship's
  # organization and their asset file, or each one queries them itself.
  class AdminSponsorEventResource < Api::ApplicationResource
    # SponsorEventStatus values by SponsorEvent#status.
    STATUSES = {
      'pending' => :SPONSOR_EVENT_STATUS_PENDING,
      'accepted' => :SPONSOR_EVENT_STATUS_ACCEPTED,
      'rejected' => :SPONSOR_EVENT_STATUS_REJECTED,
      'withdrawn' => :SPONSOR_EVENT_STATUS_WITHDRAWN,
    }.freeze #: Hash[String, Symbol]

    with_protobuf Rk::SponsorApp::AdminSponsorEvent do
      attributes :id, :slug, :title, :url, :link_name, :price, :capacity, :location_en, :location_local, :admin_comment
      attributes starts_at: :timestamp
      attributes policy_acknowledged_at: :timestamp, if: proc { |event| event.policy_acknowledged_at }
      attribute(:status) { |event| STATUSES.fetch(event.status) }
      one :sponsorship, resource: Api::SponsorshipSummaryResource
      attribute(:co_hosts) do |event|
        co_hosts = params.fetch(:co_hosts)
        event.co_host_sponsorship_ids.filter_map { co_hosts[it] }.map { Api::SponsorshipSummaryResource.new(it).as_protobuf }
      end
      attribute(:hero_image_uploaded) { |event| !event.asset_file.nil? }
    end
  end
end
