# typed: strict
# frozen_string_literal: true

module Api
  module Admin
    # For RPCs under `authorize :conference` acting on a sponsorship's expense report or files.
    # @requires_ancestor: Api::Admin::ApplicationController
    module ExpenseReportLookup
      include Api::ExpenseReportWriting

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
    end
  end
end
