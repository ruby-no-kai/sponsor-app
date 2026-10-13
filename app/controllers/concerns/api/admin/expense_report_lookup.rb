# typed: strict
# frozen_string_literal: true

module Api
  module Admin
    # For RPCs under `authorize :conference` acting on a sponsorship's expense report or files.
    # @requires_ancestor: Api::Admin::ApplicationController
    module ExpenseReportLookup
      #: (Sponsorship) -> ExpenseReport
      private def expense_report_of(sponsorship)
        sponsorship.expense_report || raise(Errors::NotFound.new(
          detail: "The sponsorship #{sponsorship.id} has no expense report.",
        ))
      end

      # Locks the report, so a review approving it waits, then refuses it if already approved. Call
      # within the transaction that changes it.
      #: (ExpenseReport) -> void
      private def lock_unapproved!(report)
        report.lock!
        refuse_approved!(report)
      end

      # An approved report and the files it was approved with take no more changes.
      #: (ExpenseReport?) -> void
      private def refuse_approved!(report)
        return unless report && report.status == 'approved'

        raise Errors::FailedPrecondition.new(
          detail: "The expense report of the sponsorship #{report.sponsorship_id} is approved and takes no more changes.",
        )
      end

      # The report as a response carries it, read again to include what the RPC wrote.
      #: (ExpenseReport) -> Rk::SponsorApp::ExpenseReport
      private def expense_report_message(report)
        Api::ExpenseReportResource.new(
          ExpenseReport.includes(line_items: :expense_line_item_files).find(report.id),
        ).as_protobuf
      end
    end
  end
end
