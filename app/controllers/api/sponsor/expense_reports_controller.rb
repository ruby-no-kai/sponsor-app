# typed: strict
# frozen_string_literal: true

module Api
  module Sponsor
    class ExpenseReportsController < Api::Sponsor::ApplicationController
      include Api::Sponsor::ExpenseReportLookup

      authorize :sponsorship
      #: () -> Rk::SponsorApp::SponsorServiceGetExpenseReportResponse
      def get_expense_report
        report = expense_report_of(custom_sponsorship)

        Rk::SponsorApp::SponsorServiceGetExpenseReportResponse.new(report: expense_report_message(report))
      end

      authorize :sponsorship
      #: () -> Rk::SponsorApp::SponsorServiceCalculateExpenseReportResponse
      def calculate_expense_report
        Rk::SponsorApp::SponsorServiceCalculateExpenseReportResponse.new(
          calculation: ExpenseReportCalculationResource.new(custom_sponsorship).as_protobuf,
        )
      end

      authorize :sponsorship
      #: () -> Rk::SponsorApp::SponsorServiceCreateExpenseReportResponse
      def create_expense_report
        sponsorship = custom_sponsorship
        report = sponsorship.expense_report
        unless report
          begin
            report = ExpenseReport.create!(sponsorship:)
          rescue ActiveRecord::RecordNotUnique
            # A concurrent call started it first.
            report = expense_report_of(sponsorship.reload)
          end
        end

        Rk::SponsorApp::SponsorServiceCreateExpenseReportResponse.new(report: expense_report_message(report))
      end
    end
  end
end
