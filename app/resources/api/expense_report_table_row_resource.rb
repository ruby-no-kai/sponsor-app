# typed: strict
# frozen_string_literal: true

module Api
  # Load sponsorships with their plan, organization and expense report, or each one queries them itself.
  class ExpenseReportTableRowResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::ExpenseReportTableRow do
      one :sponsorship, source: proc { self }, resource: Api::SponsorshipSummaryResource
      attribute(:displayed_plan_name, if: proc { |sponsorship| sponsorship.plan_name }, &:plan_name)
      attribute(:total_fee) { |sponsorship| ExpenseReportCalculationResource.new(sponsorship).as_protobuf.total_fee }
      attribute(:report, if: proc { |sponsorship| sponsorship.expense_report }) do |sponsorship|
        Api::ExpenseReportTableRowReportResource.new(sponsorship.expense_report).as_protobuf
      end
    end
  end
end
