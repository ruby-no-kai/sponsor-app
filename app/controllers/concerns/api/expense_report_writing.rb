# typed: strict
# frozen_string_literal: true

module Api
  # What the RPCs changing an expense report's line items share, whichever service they serve.
  # @requires_ancestor: Api::ApplicationController
  module ExpenseReportWriting
    # The report as a response carries it, read again to include what the RPC wrote.
    #: (ExpenseReport) -> Rk::SponsorApp::ExpenseReport
    private def expense_report_message(report)
      Api::ExpenseReportResource.new(
        ExpenseReport.includes(line_items: :expense_line_item_files).find(report.id),
      ).as_protobuf
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

    # Recalculates the totals, and rewrites the snapshot under review while the report is submitted.
    #: (ExpenseReport, ?reopen_rejected: bool) -> void
    private def recalculate!(report, reopen_rejected: false)
      report.reload
      report.reopen_if_rejected if reopen_rejected
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
