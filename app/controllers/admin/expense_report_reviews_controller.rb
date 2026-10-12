# typed: strict
# frozen_string_literal: true

module Admin
  class ExpenseReportReviewsController < Admin::ApplicationController
    before_action :set_conference
    before_action :set_sponsorship
    before_action :set_expense_report

    #: () -> void
    def create
      submission = expense_report.current_submission
      raise ActiveRecord::RecordNotFound unless submission

      ExpenseReportReview.create_for!(
        submission,
        action: params.fetch(:action_type),
        comment: params[:comment].presence,
        staff: current_staff,
      )

      render json: ExpenseReportResource.new(expense_report.reload).to_h
    rescue ActiveRecord::RecordInvalid => e
      render status: :unprocessable_content, json: {error: e.record.errors.full_messages}
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
    private def sponsorship = Must.because(@sponsorship) { "set_sponsorship runs before every action" }

    #: () -> ExpenseReport
    private def expense_report = Must.because(@expense_report) { "set_expense_report runs before every action" }
  end
end
