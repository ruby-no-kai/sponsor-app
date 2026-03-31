# frozen_string_literal: true

class ExpenseReportsController < ApplicationController
  before_action :require_sponsorship_session
  before_action :set_conference
  before_action :require_custom_sponsorship
  before_action :set_expense_report, only: [:show, :update, :calculate]

  def create
    @expense_report = current_sponsorship.build_expense_report
    @expense_report.save!

    respond_to do |format|
      format.html { redirect_to user_conference_sponsorship_expense_report_path(@conference) }
      format.json { render json: report_json }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: report_json }
    end
  end

  def update
    @expense_report.reopen_if_rejected
    @expense_report.recalculate_totals
    @expense_report.refresh_submission_snapshot
    @expense_report.save!

    render json: report_json
  end

  def calculate
    plan = current_sponsorship.plan
    render json: {
      tax_rates: Rails.configuration.x.expense_report.tax_rates.map { |r| r.to_f.to_s },
      plan_price: plan&.price.to_s,
      plan_price_booth: plan&.price_booth.to_s,
      booth_assigned: current_sponsorship.booth_assigned?,
      total_fee: calculate_total_fee.to_s,
    }
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

  private def calculate_total_fee
    plan = current_sponsorship.plan
    return 0 unless plan

    fee = plan.price
    fee += plan.price_booth if current_sponsorship.booth_assigned?
    fee
  end
end
