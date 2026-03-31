# frozen_string_literal: true

class ExpenseReportSubmissionsController < ApplicationController
  before_action :require_sponsorship_session
  before_action :set_conference
  before_action :require_custom_sponsorship
  before_action :set_expense_report

  def create
    @expense_report.submit!

    render json: report_json
  end

  def destroy
    @expense_report.withdraw_submission!

    render json: report_json
  end

  private def set_conference
    @conference = current_conference
  end

  private def require_custom_sponsorship
    render status: :forbidden, json: {error: 'Not a custom sponsorship'} unless current_sponsorship.customization
  end

  private def set_expense_report
    @expense_report = current_sponsorship.expense_report
    raise ActiveRecord::RecordNotFound unless @expense_report
  end

  private def report_json
    ExpenseReportResource.new(@expense_report.reload).to_h
  end
end
