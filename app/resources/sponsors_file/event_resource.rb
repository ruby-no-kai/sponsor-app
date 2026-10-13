# typed: strict
# frozen_string_literal: true

module SponsorsFile
  # Binds an accepted SponsorEvent.
  class EventResource < ApplicationResource
    with_protobuf Rk::SponsorApp::SponsorsFile::Event do
      attributes :id, :slug, :title
      attribute(:starts_at) { |event| event.starts_at.iso8601 }
      attributes :url, :price, :capacity, :location_en, :location_local, :link_name
      attribute(:hosts) { |event| HostResource.new(event.all_host_sponsorships.sort_by(&:id)).to_h }
    end
  end
end
