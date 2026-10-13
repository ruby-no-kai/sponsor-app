# typed: strict
# frozen_string_literal: true

module SponsorsFile
  # Binds a Sponsorship hosting a sponsor event.
  class HostResource < ApplicationResource
    with_protobuf Rk::SponsorApp::SponsorsFile::Host do
      attributes :slug, :name, :url
    end
  end
end
