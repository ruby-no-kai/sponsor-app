# typed: strict
# frozen_string_literal: true

module Api
  # Takes `params[:submission_open]`, whether the event's conference takes event submissions, which
  # an event's `editable` depends on.
  class SponsorEventResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::SponsorEvent do
      attributes :id, :title, :url, :price, :capacity, :location_en, :location_local, :admin_comment
      attributes starts_at: :timestamp
      attributes policy_acknowledged_at: :timestamp, if: proc { |event| event.policy_acknowledged_at }
      attribute(:status) { |event| Api::AdminSponsorEventResource::STATUSES.fetch(event.status) }
      one :asset_file, resource: Api::SponsorEventAssetFileResource, if: proc { |event| event.asset_file }
      attribute(:editable) { |event| params.fetch(:submission_open) && event.editable_by_sponsor? }
    end
  end
end
