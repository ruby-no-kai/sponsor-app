# typed: strict
# frozen_string_literal: true

module Api
  # Load reports with their sponsorship and its plan, or each one queries them itself.
  class ExpenseReportSummaryResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::ExpenseReportSummary do
      attribute(:status) { |report| :"STATUS_#{report.status.upcase}" }
      attribute(:total_amount) { |report| Api::ExpenseReportSummaryResource.amount(report.total_amount) }
      attribute(:fee, if: proc { |report| Api::ExpenseReportSummaryResource.fee_of_maybe(report) }) do |report|
        Api::ExpenseReportSummaryResource.amount(Api::ExpenseReportSummaryResource.fee_of(report))
      end
      attribute(:remaining, if: proc { |report| Api::ExpenseReportSummaryResource.fee_of_maybe(report) }) do |report|
        Api::ExpenseReportSummaryResource.amount(Api::ExpenseReportSummaryResource.fee_of(report) - report.total_amount)
      end
    end

    # The fee the report's expenses are offset against, or nil while the plan is undetermined.
    #: (ExpenseReport) -> BigDecimal?
    def self.fee_of_maybe(report)
      sponsorship = Must.expect(report.sponsorship)
      plan = sponsorship.plan
      return unless plan

      sponsorship.booth_assigned? ? plan.price + plan.price_booth : plan.price
    end

    #: (ExpenseReport) -> BigDecimal
    def self.fee_of(report) = Must.because(fee_of_maybe(report)) { 'fee and remaining are set only for a determined plan' }

    # The amount as a decimal string in the digits the fee is settled in.
    #: (BigDecimal) -> String
    def self.amount(value)
      precision = Rails.configuration.x.expense_report.decimal #: Integer
      ActiveSupport::NumberHelper.number_to_rounded(value, precision:)
    end
  end
end
