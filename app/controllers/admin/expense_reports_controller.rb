# frozen_string_literal: true

module Admin
  class ExpenseReportsController < Admin::ApplicationController
    before_action :set_conference
    before_action :set_sponsorship, except: [:index]
    before_action :set_expense_report, except: [:index]

    def index
      @sponsorships = @conference.sponsorships
        .where(customization: true)
        .includes(:plan, :expense_report)
        .order(:name)
    end

    def show
      respond_to do |format|
        format.html
        format.json { render json: report_json }
      end
    end

    def update
      @expense_report.recalculate_totals
      @expense_report.refresh_submission_snapshot
      @expense_report.save!

      render json: report_json
    end

    def calculate
      plan = @sponsorship.plan
      render json: {
        tax_rates: Rails.configuration.x.expense_report.tax_rates.map { |r| r.to_f.to_s },
        plan_price: plan&.price.to_s,
        plan_price_booth: plan&.price_booth.to_s,
        booth_assigned: @sponsorship.booth_assigned?,
        total_fee: calculate_total_fee.to_s,
      }
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

    private def report_json
      ExpenseReportResource.new(@expense_report.reload).to_h
    end

    private def calculate_total_fee
      plan = @sponsorship.plan
      return 0 unless plan

      fee = plan.price
      fee += plan.price_booth if @sponsorship.booth_assigned?
      fee
    end
  end
end
