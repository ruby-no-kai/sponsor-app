# typed: strict
# frozen_string_literal: true

module Api
  class SponsorshipApplicationBillingContactResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::SponsorshipApplication::BillingContact do
      attributes :email, :address, :organization, :name
      attributes :unit, if: proc { |contact| contact.unit.present? }
    end
  end
end
