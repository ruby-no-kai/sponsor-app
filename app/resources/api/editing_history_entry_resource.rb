# typed: strict
# frozen_string_literal: true

module Api
  # Publishes a record that includes EditingHistory. Load entries with their staff, or each one
  # loads its own.
  class EditingHistoryEntryResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::EditingHistoryEntry do
      attributes :id
      attributes created_at: :timestamp
      attribute(:staff_login, if: proc { |entry| entry.staff }) { |entry| entry.staff&.login }
      attribute(:changes) do |entry|
        entry.diff.map { Api::EditingHistoryChangeResource.new(EditingHistoryChange.new(it)).as_protobuf }
      end
    end
  end
end
