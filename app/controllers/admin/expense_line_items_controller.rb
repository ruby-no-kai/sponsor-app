# frozen_string_literal: true

module Admin
  class ExpenseLineItemsController < Admin::ApplicationController
    before_action :set_conference
    before_action :set_sponsorship
    before_action :set_expense_report
    before_action :set_line_item, only: [:update, :destroy]

    def create
      @line_item = @expense_report.line_items.build(line_item_params)
      @line_item.assign_next_position

      ActiveRecord::Base.transaction do
        @line_item.save!
        sync_file_ids if params[:expense_line_item]&.key?(:file_ids)
        after_line_item_change
      end

      render json: report_json
    end

    def update
      ActiveRecord::Base.transaction do
        @line_item.assign_attributes(line_item_params)
        sync_file_ids if params[:expense_line_item]&.key?(:file_ids)
        @line_item.save!
        reindex_positions if @line_item.saved_change_to_position?
        after_line_item_change
      end

      render json: report_json
    end

    def destroy
      ActiveRecord::Base.transaction do
        @line_item.destroy!
        after_line_item_change
      end

      render json: report_json
    end

    private def set_conference
      @conference = Conference.find_by!(slug: params[:conference_slug])
      check_staff_conference_authorization!(@conference)
    end

    private def set_sponsorship
      @sponsorship = Sponsorship.where(conference: @conference).find(params[:sponsorship_id])
    end

    private def set_expense_report
      @expense_report = @sponsorship.expense_report
      raise ActiveRecord::RecordNotFound unless @expense_report
    end

    private def set_line_item
      @line_item = @expense_report.line_items.find(params[:id])
    end

    private def line_item_params
      params.require(:expense_line_item).permit(:title, :notes, :amount, :tax_rate, :tax_amount, :preliminal, :position)
    end

    private def sync_file_ids
      new_ids = Array(params[:expense_line_item][:file_ids]).map(&:to_i)
      current_ids = @line_item.expense_file_ids

      (new_ids - current_ids).each do |file_id|
        file = @sponsorship.expense_files.find(file_id)
        @line_item.expense_line_item_files.create!(expense_file: file)
      end

      (current_ids - new_ids).each do |file_id|
        @line_item.expense_line_item_files.find_by!(expense_file_id: file_id).destroy!
      end
    end

    private def reindex_positions
      target_position = @line_item.position
      items = @expense_report.line_items.reload.where.not(id: @line_item.id).order(:position, :id).to_a
      insert_idx = items.index { |i| i.position >= target_position } || items.length
      items.insert(insert_idx, @line_item)
      items.each_with_index do |item, idx|
        new_pos = idx + 1
        item.update_column(:position, new_pos) if item.position != new_pos # rubocop:disable Rails/SkipsModelValidations
      end
    end

    private def after_line_item_change
      @expense_report.reload
      @expense_report.recalculate_totals
      @expense_report.refresh_submission_snapshot
      @expense_report.save!
    end

    private def report_json
      ExpenseReportResource.new(@expense_report.reload).to_h
    end
  end
end
