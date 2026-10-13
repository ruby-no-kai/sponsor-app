# typed: strict
# frozen_string_literal: true

module Api
  class ExpenseFileResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::ExpenseFile do
      attributes :id
      attributes :filename, if: proc { |file| !file.filename.nil? }
      attribute(:content_type) { |file| file.content_type.to_s }
      attributes created_at: :timestamp
    end
  end
end
