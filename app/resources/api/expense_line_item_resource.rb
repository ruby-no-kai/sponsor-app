# typed: strict
# frozen_string_literal: true

module Api
  # Load line items with their expense_line_item_files, or each one queries its own.
  class ExpenseLineItemResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::ExpenseLineItem do
      attributes :id, :title, :preliminal, :position
      attributes :notes, if: proc { |line_item| !line_item.notes.nil? }
      attribute(:amount) { |line_item| line_item.amount.to_s }
      attribute(:tax_rate, if: proc { |line_item| line_item.tax_rate }) { |line_item| line_item.tax_rate.to_s }
      attribute(:tax_amount) { |line_item| line_item.tax_amount.to_s }
      attribute(:file_ids) { |line_item| line_item.expense_line_item_files.sort_by(&:id).map(&:expense_file_id) }
    end
  end
end
