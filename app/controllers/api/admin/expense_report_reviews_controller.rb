# typed: strict
# frozen_string_literal: true

module Api
  module Admin
    class ExpenseReportReviewsController < Api::Admin::ApplicationController
      include Api::Admin::SponsorshipLookup
      include Api::Admin::ExpenseReportLookup

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceCreateExpenseReportReviewResponse
      def create_expense_report_review
        input = connect_request.input #: Rk::SponsorApp::ExpenseReportReviewInput
        report = expense_report_of(find_sponsorship)
        submission = report.current_submission || raise(Errors::NotFound.new(
          detail: "The expense report of the sponsorship #{report.sponsorship_id} has never been submitted.",
        ))
        # A withdrawn submission stays the latest until the next one.
        if report.status == 'draft'
          raise Errors::FailedPrecondition.new(
            detail: "The expense report of the sponsorship #{report.sponsorship_id} is a draft awaiting submission.",
          )
        end

        ExpenseReportReview.create_for!(
          submission,
          action: review_action_of(input),
          comment: (input.comment if input.has_comment?),
          staff: current_staff,
        )

        Rk::SponsorApp::AdminServiceCreateExpenseReportReviewResponse.new(report: expense_report_message(report))
      end

      #: (Rk::SponsorApp::ExpenseReportReviewInput) -> String
      private def review_action_of(input)
        case input.action
        when :ACTION_APPROVE then 'approve'
        when :ACTION_REJECT then 'reject'
        else raise ArgumentError, "buf.validate admits no review action #{input.action.inspect}"
        end
      end
    end
  end
end
