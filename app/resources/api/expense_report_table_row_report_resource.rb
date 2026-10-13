# typed: strict
# frozen_string_literal: true

module Api
  class ExpenseReportTableRowReportResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::ExpenseReportTableRow::Report do
      attribute(:status) { |report| :"STATUS_#{report.status.upcase}" }
      attribute(:total_amount) { |report| report.total_amount.to_s }
      attribute(:total_tax_amount) { |report| report.total_tax_amount.to_s }
      attribute(:offset) do |report|
        fee = ExpenseReportCalculationResource.new(Must.expect(report.sponsorship)).as_protobuf.total_fee
        (fee.to_d - report.total_amount).to_s
      end
    end
  end
end
