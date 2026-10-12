# typed: strict
# frozen_string_literal: true

module Admin
  class ExpenseReportsController < Admin::ApplicationController
    before_action :set_conference
    before_action :set_sponsorship, except: [:index]
    before_action :set_expense_report, except: [:index]

    #: () -> void
    def index
      @sponsorships = conference.sponsorships
        .where(customization: true)
        .includes(:plan, :expense_report)
        .order(:name) #: Sponsorship::PrivateAssociationRelation?
    end

    #: () -> void
    def show
      respond_to do |format|
        format.html
        format.json { render json: report_json }
      end
    end

    #: () -> void
    def update
      expense_report.recalculate_totals
      expense_report.refresh_submission_snapshot
      expense_report.save!

      render json: report_json
    end

    #: () -> void
    def calculate
      plan = sponsorship.plan
      tax_rates = Rails.configuration.x.expense_report.tax_rates #: Array[Rational]
      decimal = Rails.configuration.x.expense_report.decimal #: Integer
      render json: {
        tax_rates: tax_rates.map { |r| r.to_f.to_s },
        decimal:,
        plan_price: plan&.price.to_s,
        plan_price_booth: plan&.price_booth.to_s,
        booth_assigned: sponsorship.booth_assigned?,
        total_fee: calculate_total_fee.to_s,
      }
    end

    #: () -> void
    private def set_conference
      @conference = Conference.find_by!(slug: params[:conference_slug]) #: Conference?
      check_staff_conference_authorization!(conference)
    end

    #: () -> void
    private def set_sponsorship
      @sponsorship = Sponsorship.where(conference:).find(params[:sponsorship_id]) #: Sponsorship?
    end

    #: () -> void
    private def set_expense_report
      @expense_report = sponsorship.expense_report #: ExpenseReport?
      raise ActiveRecord::RecordNotFound unless @expense_report
    end

    #: () -> Conference
    private def conference = Must.because(@conference) { "set_conference runs before every action" }

    #: () -> Sponsorship
    private def sponsorship = Must.because(@sponsorship) { "set_sponsorship runs before every action but index" }

    #: () -> ExpenseReport
    private def expense_report = Must.because(@expense_report) { "set_expense_report runs before every action but index" }

    #: () -> Hash[String, untyped]
    private def report_json
      ExpenseReportResource.new(expense_report.reload).to_h
    end

    #: () -> (Integer | BigDecimal)
    private def calculate_total_fee
      plan = sponsorship.plan
      return 0 unless plan

      fee = plan.price
      fee += plan.price_booth if sponsorship.booth_assigned?
      fee
    end
  end
end
