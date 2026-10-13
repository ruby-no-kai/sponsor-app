# typed: strict
# frozen_string_literal: true

module Api
  module Sponsor
    # For RPCs under `authorize :sponsorship` acting on the sponsorship's expense report or files.
    # @requires_ancestor: Api::Sponsor::ApplicationController
    module ExpenseReportLookup
      include Api::ExpenseReportWriting

      # Only a sponsorship with a confirmed custom package has an expense report.
      #: () -> Sponsorship
      private def custom_sponsorship
        sponsorship = current_sponsorship
        raise Errors::PermissionDenied.new(detail: 'Only a custom sponsorship has an expense report.') unless sponsorship.customization

        sponsorship
      end

      #: (Sponsorship) -> ExpenseReport
      private def expense_report_of(sponsorship)
        sponsorship.expense_report || raise(Errors::NotFound.new(detail: 'You have not started an expense report.'))
      end

      # Locks the report, so a submission waits, then refuses it unless the sponsor may change it.
      # Call within the transaction that changes it.
      #: (ExpenseReport) -> void
      private def lock_editable!(report)
        report.lock!
        refuse_unless_editable!(report)
      end

      # A submitted report is under review and an approved one is final, so neither takes changes. A
      # rejected one does, and becomes a draft again.
      #: (ExpenseReport?) -> void
      private def refuse_unless_editable!(report)
        return if report.nil? || %w[draft rejected].include?(report.status)

        raise Errors::FailedPrecondition.new(
          detail: "The expense report is #{report.status} and takes no changes.",
        )
      end
    end
  end
end
