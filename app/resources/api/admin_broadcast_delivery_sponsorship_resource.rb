# typed: strict
# frozen_string_literal: true

module Api
  class AdminBroadcastDeliverySponsorshipResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::AdminBroadcastDelivery::Sponsorship do
      attributes :id, :name
      attribute(:conference_slug) { |sponsorship| Must.expect(sponsorship.conference).slug }
    end
  end
end
