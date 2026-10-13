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
        format.json { render json: expense_report.reload.to_resource.to_h }
      end
    end

    #: () -> void
    def update
      expense_report.recalculate_totals
      expense_report.refresh_submission_snapshot
      expense_report.save!

      render json: expense_report.reload.to_resource.to_h
    end

    #: () -> void
    def calculate
      render proto_json: ExpenseReportCalculationResource.new(sponsorship).as_protobuf
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
  end
end
