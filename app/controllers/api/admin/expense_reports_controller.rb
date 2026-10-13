# typed: strict
# frozen_string_literal: true

module Api
  module Admin
    class ExpenseReportsController < Api::Admin::ApplicationController
      include Api::Admin::SponsorshipLookup
      include Api::Admin::ExpenseReportLookup

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceListExpenseReportsResponse
      def list_expense_reports
        sponsorships = conference.sponsorships.where(customization: true)
          .includes(:plan, :organization, :expense_report).order(:name)

        Rk::SponsorApp::AdminServiceListExpenseReportsResponse.new(
          rows: sponsorships.map { Api::ExpenseReportTableRowResource.new(it).as_protobuf },
        )
      end

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceGetExpenseReportResponse
      def get_expense_report
        sponsorship = find_sponsorship

        Rk::SponsorApp::AdminServiceGetExpenseReportResponse.new(
          report: expense_report_message(expense_report_of(sponsorship)),
          sponsorship: Api::SponsorshipSummaryResource.new(sponsorship).as_protobuf,
        )
      end

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceCalculateExpenseReportResponse
      def calculate_expense_report
        Rk::SponsorApp::AdminServiceCalculateExpenseReportResponse.new(
          calculation: ExpenseReportCalculationResource.new(find_sponsorship).as_protobuf,
        )
      end
    end
  end
end
