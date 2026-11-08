# typed: strict
# frozen_string_literal: true

module Api
  class StaffResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::Staff do
      attributes :login, :name
      attributes :avatar_url, if: proc { |staff| staff.avatar_url.present? }
      attribute(:restricted, &:restricted?)
    end
  end
end
