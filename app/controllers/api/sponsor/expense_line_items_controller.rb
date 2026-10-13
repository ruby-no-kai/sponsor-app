# typed: strict
# frozen_string_literal: true

module Api
  module Sponsor
    # Every change recalculates the report's totals. A rejected report takes it and becomes a draft
    # again.
    class ExpenseLineItemsController < Api::Sponsor::ApplicationController
      include Api::Sponsor::ExpenseReportLookup

      authorize :sponsorship
      #: () -> Rk::SponsorApp::SponsorServiceCreateExpenseLineItemResponse
      def create_expense_line_item
        input = connect_request.input #: Rk::SponsorApp::ExpenseLineItemInput
        sponsorship = custom_sponsorship
        report = expense_report_of(sponsorship)
        files = expense_files_of(sponsorship, input)

        line_item = ActiveRecord::Base.transaction do
          lock_editable!(report)
          item = report.line_items.build
          assign_input(item, input)
          item.assign_next_position
          item.save!
          attach_files(item, files)
          move(report, item, input.position) if input.has_position?
          recalculate!(report, reopen_rejected: true)
          item
        end

        report_message = expense_report_message(report)
        Rk::SponsorApp::SponsorServiceCreateExpenseLineItemResponse.new(
          line_item: line_item_message_in(report_message, line_item),
          report: report_message,
        )
      end

      authorize :sponsorship
      #: () -> Rk::SponsorApp::SponsorServiceUpdateExpenseLineItemResponse
      def update_expense_line_item
        input = connect_request.input #: Rk::SponsorApp::ExpenseLineItemInput
        sponsorship = custom_sponsorship
        report = expense_report_of(sponsorship)
        line_item = find_line_item(report)
        files = expense_files_of(sponsorship, input)

        ActiveRecord::Base.transaction do
          lock_editable!(report)
          assign_input(line_item, input)
          attach_files(line_item, files)
          line_item.save!
          move(report, line_item, input.position) if input.has_position?
          recalculate!(report, reopen_rejected: true)
        end

        report_message = expense_report_message(report)
        Rk::SponsorApp::SponsorServiceUpdateExpenseLineItemResponse.new(
          line_item: line_item_message_in(report_message, line_item),
          report: report_message,
        )
      end

      authorize :sponsorship
      #: () -> Rk::SponsorApp::SponsorServiceDeleteExpenseLineItemResponse
      def delete_expense_line_item
        report = expense_report_of(custom_sponsorship)
        line_item = find_line_item(report)

        ActiveRecord::Base.transaction do
          lock_editable!(report)
          line_item.destroy!
          recalculate!(report, reopen_rejected: true)
        end

        Rk::SponsorApp::SponsorServiceDeleteExpenseLineItemResponse.new(report: expense_report_message(report))
      end

      # A line item of another sponsorship's report is not found.
      #: (ExpenseReport) -> ExpenseLineItem
      private def find_line_item(report)
        id = connect_request.line_item_id #: Integer
        report.line_items.find_by(id:) || raise(Errors::NotFound.new(detail: "The expense report has no line item #{id}."))
      end
    end
  end
end
