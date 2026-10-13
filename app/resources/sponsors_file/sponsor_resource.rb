# typed: strict
# frozen_string_literal: true

module SponsorsFile
  # Binds a Sponsorship with presence.
  class SponsorResource < ApplicationResource
    with_protobuf Rk::SponsorApp::SponsorsFile::Sponsor do
      attributes :id
      attribute(:asset_file_id) { |sponsorship| sponsorship.asset_file&.id }
      attribute(:base_plan) { |sponsorship| ApplicationResource.base_plan_of(sponsorship) }
      attributes :plan_name, :slug, :name
      attribute(:url) { |sponsorship| sponsorship.url.strip }
      attributes :profile
    end
  end
end
