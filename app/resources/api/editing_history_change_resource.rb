# typed: strict
# frozen_string_literal: true

require 'google/protobuf/well_known_types' # Defines Value.from_ruby.

module Api
  class EditingHistoryChangeResource < Api::ApplicationResource
    OPERATIONS = {
      '+' => :OPERATION_ADDED,
      '-' => :OPERATION_REMOVED,
      '~' => :OPERATION_CHANGED,
    }.freeze #: Hash[String, Symbol]

    with_protobuf Rk::SponsorApp::EditingHistoryEntry::Change do
      attributes :path
      attribute(:operation) { |change| OPERATIONS.fetch(change.operation) }
      attribute(:old_value, if: proc { |change| change.old_value? }) do |change|
        Google::Protobuf::Value.from_ruby(change.old_value)
      end
      attribute(:new_value, if: proc { |change| change.new_value? }) do |change|
        Google::Protobuf::Value.from_ruby(change.new_value)
      end
    end
  end
end
