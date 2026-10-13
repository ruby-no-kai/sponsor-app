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

      # The files the input attaches, in its order. A file of another sponsorship is not found.
      #: (Sponsorship, Rk::SponsorApp::ExpenseLineItemInput) -> Array[ExpenseFile]
      private def expense_files_of(sponsorship, input)
        ids = input.file_ids.to_a #: Array[Integer]
        files = sponsorship.expense_files.where(id: ids).index_by(&:id)
        ids.map do |id|
          files[id] || raise(Errors::NotFound.new(detail: "The sponsorship #{sponsorship.id} has no expense file #{id}."))
        end
      end

      #: (ExpenseLineItem, Rk::SponsorApp::ExpenseLineItemInput) -> void
      private def assign_input(line_item, input)
        line_item.assign_attributes(
          title: input.title,
          notes: (input.notes if input.has_notes?),
          amount: input.amount,
          tax_rate: (input.tax_rate if input.has_tax_rate?),
          tax_amount: input.tax_amount,
          preliminal: input.preliminal,
        )
        refuse_unoffered_tax_rate!(line_item)
      end

      # The editors offer only the configured rates, which the model itself leaves unchecked.
      #: (ExpenseLineItem) -> void
      private def refuse_unoffered_tax_rate!(line_item)
        rate = line_item.tax_rate
        tax_rates = Rails.configuration.x.expense_report.tax_rates #: Array[Rational]
        return if rate.nil? || tax_rates.include?(rate)

        line_item.errors.add(:tax_rate, :inclusion, value: rate)
        raise ActiveRecord::RecordInvalid, line_item
      end

      # Replaces the files attached to the line item, keeping the attachments of files that stay.
      #: (ExpenseLineItem, Array[ExpenseFile]) -> void
      private def attach_files(line_item, files)
        attachments = line_item.expense_line_item_files.to_a
        file_ids = files.map(&:id)
        attachments.reject { file_ids.include?(it.expense_file_id) }.each(&:destroy!)

        attached_ids = attachments.map(&:expense_file_id)
        files.reject { attached_ids.include?(it.id) }.each do |file|
          line_item.expense_line_item_files.create!(expense_file: file)
        end
      end

      # Puts the line item at a place among the report's line items, 1 being the first, and
      # renumbers them all from 1 in their order.
      #: (ExpenseReport, ExpenseLineItem, Integer) -> void
      private def move(report, line_item, place)
        items = report.line_items.where.not(id: line_item.id).order(:position, :id).to_a
        items.insert((place - 1).clamp(0, items.length), line_item)
        items.each.with_index(1) do |item, position|
          item.update_column(:position, position) if item.position != position # rubocop:disable Rails/SkipsModelValidations
        end
      end

      #: (ExpenseReport) -> void
      private def recalculate!(report)
        report.reload
        report.recalculate_totals
        report.refresh_submission_snapshot
        report.save!
      end

      #: (Rk::SponsorApp::ExpenseReport, ExpenseLineItem) -> Rk::SponsorApp::ExpenseLineItem
      private def line_item_message_in(report_message, line_item)
        Must.because(report_message.line_items.find { it.id == line_item.id }) do
          'the report is read after the line item was saved to it'
        end
      end
    end
  end
end
