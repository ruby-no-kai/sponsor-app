# typed: strict
# frozen_string_literal: true

module Api
  class SponsorshipApplicationResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::SponsorshipApplication do
      attributes :name, :url, :profile, :booth_requested, :fallback_option
      attributes :plan_id, if: proc { |sponsorship| sponsorship.plan_id }
      attributes :number_of_additional_attendees, if: proc { |sponsorship| sponsorship.number_of_additional_attendees }

      one :contact, resource: Api::SponsorshipApplicationContactResource, if: proc { |sponsorship| sponsorship.contact }
      one :alternate_billing_contact, resource: Api::SponsorshipApplicationBillingContactResource,
        if: proc { |sponsorship| sponsorship.alternate_billing_contact }

      attribute(:billing_request) { |sponsorship| sponsorship.billing_request&.body.to_s }
      attribute(:customization_request) { |sponsorship| sponsorship.customization_request&.body.to_s }
      attribute(:note) { |sponsorship| sponsorship.note&.body.to_s }

      one :asset_file, resource: Api::SponsorshipAssetFileResource, if: proc { |sponsorship| sponsorship.asset_file }
    end
  end
end
