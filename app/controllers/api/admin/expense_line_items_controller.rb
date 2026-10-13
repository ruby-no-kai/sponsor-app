# typed: strict
# frozen_string_literal: true

module Api
  module Admin
    # Every change recalculates the report's totals and, while it is submitted, rewrites the
    # snapshot under review.
    class ExpenseLineItemsController < Api::Admin::ApplicationController
      include Api::Admin::SponsorshipLookup
      include Api::Admin::ExpenseReportLookup

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceCreateExpenseLineItemResponse
      def create_expense_line_item
        input = connect_request.input #: Rk::SponsorApp::ExpenseLineItemInput
        sponsorship = find_sponsorship
        report = expense_report_of(sponsorship)
        files = expense_files_of(sponsorship, input)

        line_item = ActiveRecord::Base.transaction do
          lock_unapproved!(report)
          item = report.line_items.build
          assign_input(item, input)
          item.assign_next_position
          item.save!
          attach_files(item, files)
          move(report, item, input.position) if input.has_position?
          recalculate!(report)
          item
        end

        report_message = expense_report_message(report)
        Rk::SponsorApp::AdminServiceCreateExpenseLineItemResponse.new(
          line_item: line_item_message_in(report_message, line_item),
          report: report_message,
        )
      end

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceUpdateExpenseLineItemResponse
      def update_expense_line_item
        input = connect_request.input #: Rk::SponsorApp::ExpenseLineItemInput
        sponsorship = find_sponsorship
        report = expense_report_of(sponsorship)
        line_item = find_line_item(report)
        files = expense_files_of(sponsorship, input)

        ActiveRecord::Base.transaction do
          lock_unapproved!(report)
          assign_input(line_item, input)
          attach_files(line_item, files)
          line_item.save!
          move(report, line_item, input.position) if input.has_position?
          recalculate!(report)
        end

        report_message = expense_report_message(report)
        Rk::SponsorApp::AdminServiceUpdateExpenseLineItemResponse.new(
          line_item: line_item_message_in(report_message, line_item),
          report: report_message,
        )
      end

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceDeleteExpenseLineItemResponse
      def delete_expense_line_item
        report = expense_report_of(find_sponsorship)
        line_item = find_line_item(report)

        ActiveRecord::Base.transaction do
          lock_unapproved!(report)
          line_item.destroy!
          recalculate!(report)
        end

        Rk::SponsorApp::AdminServiceDeleteExpenseLineItemResponse.new(report: expense_report_message(report))
      end

      # A line item of another sponsorship's report is not found, even one of the same conference.
      #: (ExpenseReport) -> ExpenseLineItem
      private def find_line_item(report)
        id = connect_request.line_item_id #: Integer
        report.line_items.find_by(id:) || raise(Errors::NotFound.new(
          detail: "The expense report of the sponsorship #{report.sponsorship_id} has no line item #{id}.",
        ))
      end
    end
  end
end
