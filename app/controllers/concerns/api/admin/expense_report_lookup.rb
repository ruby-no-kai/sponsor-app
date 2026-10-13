# typed: strict
# frozen_string_literal: true

module Api
  module Admin
    # For RPCs under `authorize :conference` acting on a sponsorship's expense report.
    # @requires_ancestor: Api::Admin::ApplicationController
    module ExpenseReportLookup
      #: (Sponsorship) -> ExpenseReport
      private def expense_report_of(sponsorship)
        sponsorship.expense_report || raise(Errors::NotFound.new(
          detail: "The sponsorship #{sponsorship.id} has no expense report.",
        ))
      end

      # The report as a response carries it, read again with its line items' files.
      #: (ExpenseReport) -> Rk::SponsorApp::ExpenseReport
      private def expense_report_message(report)
        Api::ExpenseReportResource.new(
          ExpenseReport.includes(line_items: :expense_line_item_files).find(report.id),
        ).as_protobuf
      end
    end
  end
end
