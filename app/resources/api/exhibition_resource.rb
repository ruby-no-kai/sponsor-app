# typed: strict
# frozen_string_literal: true

module Api
  class ExhibitionResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::Exhibition do
      attribute(:description) { |exhibition| exhibition.description.to_s }
    end
  end
end
