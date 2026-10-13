# typed: strict
# frozen_string_literal: true

class ExpenseReportSubmissionsController < ApplicationController
  before_action :require_sponsorship_session
  before_action :set_conference
  before_action :require_custom_sponsorship
  before_action :set_expense_report

  #: () -> void
  def create
    expense_report.submit!

    SlackWebhookJob.perform_later(
      text: ":receipt: #{current_sponsorship.name} submitted an <#{conference_sponsorship_expense_report_url(conference, current_sponsorship)}|expense report> (#{expense_report.total_amount} + #{expense_report.total_tax_amount} tax)",
      hook_name: :feed,
    )

    render json: expense_report.reload.to_resource.to_h
  end

  #: () -> void
  def destroy
    expense_report.withdraw_submission!

    render json: expense_report.reload.to_resource.to_h
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
  private def expense_report = Must.because(@expense_report) { "set_expense_report runs before every action" }
end
