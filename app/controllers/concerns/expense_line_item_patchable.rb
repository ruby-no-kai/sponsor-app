# typed: strict
# frozen_string_literal: true

require 'active_support/concern'

# Reads the Rk::SponsorApp::ExpenseLineItemPatch that the expense report editor sends to create or update a
# line item. A body naming no field is a bad request, as is one whose fields break ExpenseLineItemInput's rules.
# @requires_ancestor: ApplicationController
module ExpenseLineItemPatchable
  extend ActiveSupport::Concern

  # Paths a field_mask may name, one per field of Rk::SponsorApp::ExpenseLineItemInput.
  FIELD_PATHS = %w[title notes amount tax_rate tax_amount preliminal position file_ids].freeze #: Array[String]

  # Checks the fields field_mask names against ExpenseLineItemInput's rules. A field it leaves out is not
  # judged, as the editor does not send it, and keeps its value or takes its default.
  # @raise [Protobufable::RequestValidatable::InvalidMessage]
  #: (Rk::SponsorApp::ExpenseLineItemPatch) -> void
  private def validate_line_item_input!(patch)
    paths = patched_paths(patch)
    input = patch.expense_line_item || Rk::SponsorApp::ExpenseLineItemInput.new
    violations = Protovalidate.collect_violations(input).select do |violation|
      paths.include?(violation.field&.elements&.first&.field_name)
    end
    return if violations.empty?

    raise Protobufable::RequestValidatable::InvalidMessage.new(violations, Rk::SponsorApp::ExpenseLineItemInput)
  end

  # Column values the patch writes, keyed by attribute name.
  #: (Rk::SponsorApp::ExpenseLineItemPatch) -> Hash[Symbol, String | Integer | bool | nil]
  private def line_item_attributes(patch)
    paths = patched_paths(patch)
    input = patch.expense_line_item || Rk::SponsorApp::ExpenseLineItemInput.new
    values = {
      title: input.title,
      notes: (input.notes if input.has_notes?),
      amount: input.amount,
      tax_rate: (input.tax_rate if input.has_tax_rate?),
      tax_amount: input.tax_amount,
      preliminal: input.preliminal,
    } #: Hash[Symbol, String | Integer | bool | nil]
    values[:position] = input.position if input.has_position?

    values.select { |name, _| paths.include?(name.to_s) }
  end

  # IDs of the files to attach in place of those attached, or nil when the patch leaves them alone.
  #: (Rk::SponsorApp::ExpenseLineItemPatch) -> Array[Integer]?
  private def line_item_file_ids(patch)
    return unless patched_paths(patch).include?('file_ids')

    patch.expense_line_item&.file_ids.to_a
  end

  #: (Rk::SponsorApp::ExpenseLineItemPatch) -> Array[String]
  private def patched_paths(patch)
    paths = patch.field_mask.to_a
    paths = merge_patch_paths if paths.empty?
    raise ActionController::BadRequest, 'field_mask names no field' if paths.empty?

    paths
  end

  # The keys of the JSON body's expense_line_item, null ones included, for a body without field_mask.
  # Deprecated, kept for editor pages loaded before field_mask.
  #: () -> Array[String]
  private def merge_patch_paths
    item = JSON.parse(request.raw_post)['expense_line_item']
    item.is_a?(Hash) ? item.keys & FIELD_PATHS : []
  rescue JSON::ParserError => e
    # The protobuf decoder accepts some bodies JSON.parse refuses, such as one repeating a key.
    raise ActionController::BadRequest, e.message
  end
end
