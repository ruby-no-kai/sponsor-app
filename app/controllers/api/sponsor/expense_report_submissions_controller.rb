# typed: strict
# frozen_string_literal: true

module Api
  module Sponsor
    class ExpenseReportSubmissionsController < Api::Sponsor::ApplicationController
      include Api::Sponsor::ExpenseReportLookup

      authorize :sponsorship
      #: () -> Rk::SponsorApp::SponsorServiceSubmitExpenseReportResponse
      def submit_expense_report
        sponsorship = custom_sponsorship
        report = expense_report_of(sponsorship)

        ActiveRecord::Base.transaction do
          report.lock!
          refuse_unless_status!(report, 'draft', 'submitted')
          report.submit!
        end

        SlackWebhookJob.perform_later(
          {text: ":receipt: #{sponsorship.name} submitted an <#{conference_sponsorship_expense_report_url(Must.expect(sponsorship.conference), sponsorship)}|expense report> (#{report.total_amount} + #{report.total_tax_amount} tax)"},
          hook_name: :feed,
        )

        Rk::SponsorApp::SponsorServiceSubmitExpenseReportResponse.new(report: expense_report_message(report))
      end

      authorize :sponsorship
      #: () -> Rk::SponsorApp::SponsorServiceWithdrawExpenseReportSubmissionResponse
      def withdraw_expense_report_submission
        report = expense_report_of(custom_sponsorship)

        ActiveRecord::Base.transaction do
          report.lock!
          refuse_unless_status!(report, 'submitted', 'withdrawn')
          report.withdraw_submission!
        end

        Rk::SponsorApp::SponsorServiceWithdrawExpenseReportSubmissionResponse.new(report: expense_report_message(report))
      end

      # `action` is what the sponsor asked for, as the error says.
      #: (ExpenseReport, String, String) -> void
      private def refuse_unless_status!(report, status, action)
        return if report.status == status

        raise Errors::FailedPrecondition.new(
          detail: "The expense report is #{report.status}, and only a #{status} one can be #{action}.",
        )
      end
    end
  end
end
