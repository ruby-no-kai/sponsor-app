# typed: strict
# frozen_string_literal: true

module Api
  # Load reports with their line items' expense_line_item_files, or each line item queries its own.
  class ExpenseReportResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::ExpenseReport do
      attributes :id, :revision
      attribute(:status) { |report| :"STATUS_#{report.status.upcase}" }
      attribute(:total_amount) { |report| report.total_amount.to_s }
      attribute(:total_tax_amount) { |report| report.total_tax_amount.to_s }
      many :line_items, resource: Api::ExpenseLineItemResource
      attribute(:files) do |report|
        Must.expect(report.sponsorship).expense_files.uploaded.order(:id).map { Api::ExpenseFileResource.new(it).as_protobuf }
      end
      one :latest_review, resource: Api::ExpenseReportReviewResource, if: proc { |report| report.latest_review }
      attributes created_at: :timestamp, updated_at: :timestamp
    end
  end
end
