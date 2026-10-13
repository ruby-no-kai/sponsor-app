# typed: strict
# frozen_string_literal: true

module Api
  class SponsorshipApplicationContactResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::SponsorshipApplication::Contact do
      attributes :email, :address, :organization, :name
      attributes :email_cc, if: proc { |contact| contact.email_cc.present? }
      attributes :unit, if: proc { |contact| contact.unit.present? }
    end
  end
end
