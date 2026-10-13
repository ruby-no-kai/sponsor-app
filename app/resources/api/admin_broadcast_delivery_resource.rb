# typed: strict
# frozen_string_literal: true

module Api
  # Load deliveries through their broadcast, with their sponsorships and those sponsorships'
  # conferences, or each one loads its own.
  class AdminBroadcastDeliveryResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::AdminBroadcastDelivery do
      attributes :id
      one :sponsorship, resource: Api::AdminBroadcastDeliverySponsorshipResource, if: proc { |delivery| delivery.sponsorship }
      attribute(:email, &:recipient)
      attribute(:cc_emails, &:recipient_ccs)
      attribute(:status) { |delivery| :"STATUS_#{delivery.status.upcase}" }
      attribute(:removable) { |delivery| delivery.ready? && Must.expect(delivery.broadcast).ready? }
    end
  end
end
