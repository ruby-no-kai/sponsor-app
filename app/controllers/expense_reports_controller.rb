# typed: strict
# frozen_string_literal: true

class ExpenseReportsController < ApplicationController
  before_action :require_sponsorship_session
  before_action :set_conference
  before_action :require_custom_sponsorship
  before_action :set_expense_report, only: [:show, :update, :calculate]

  #: () -> void
  def create
    @expense_report = current_sponsorship.expense_report
    unless @expense_report
      begin
        @expense_report = ExpenseReport.create!(sponsorship: current_sponsorship)
      rescue ActiveRecord::RecordNotUnique
        @expense_report = current_sponsorship.reload_expense_report
      end
    end

    respond_to do |format|
      format.html { redirect_to user_conference_sponsorship_expense_report_path(conference) }
      format.json { render json: expense_report.reload.to_resource.to_h }
    end
  end

  #: () -> void
  def show
    respond_to do |format|
      format.html
      format.json { render json: expense_report.reload.to_resource.to_h }
    end
  end

  #: () -> void
  def update
    expense_report.reopen_if_rejected
    expense_report.recalculate_totals
    expense_report.refresh_submission_snapshot
    expense_report.save!

    render json: expense_report.reload.to_resource.to_h
  end

  #: () -> void
  def calculate
    render proto_json: ExpenseReportCalculationResource.new(current_sponsorship).as_protobuf
  end

  #: () -> void
  private def set_conference
    @conference = current_conference #: Conference?
  end

  #: () -> void
  private def require_custom_sponsorship
    render status: :forbidden, json: {error: 'Not a custom sponsorship'} unless current_sponsorship.customization
  end

  #: () -> void
  private def set_expense_report
    @expense_report = current_sponsorship.expense_report #: ExpenseReport?
    raise ActiveRecord::RecordNotFound unless @expense_report
  end

  #: () -> Conference
  private def conference = Must.because(@conference) { "set_conference runs before every action" }

  #: () -> ExpenseReport
  private def expense_report = Must.because(@expense_report) { "set_expense_report or create assigns @expense_report" }
end
