# typed: strict
# frozen_string_literal: true

module Api
  class AdminSponsorshipSponsorEventResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::AdminSponsorship::SponsorEvent do
      attributes :id, :title
      attributes starts_at: :timestamp
      attribute(:status) { |event| Api::AdminSponsorEventResource::STATUSES.fetch(event.status) }
    end
  end
end
