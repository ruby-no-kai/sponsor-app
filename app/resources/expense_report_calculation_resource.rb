# typed: strict
# frozen_string_literal: true

require 'protobufable/alba_binding'

# Binds a Sponsorship to the fee figures its expense report editor shows. Amounts are decimal strings.
class ExpenseReportCalculationResource
  include Alba::Resource
  include Protobufable::AlbaBinding

  with_protobuf Rk::SponsorApp::ExpenseReportCalculation do
    attribute(:tax_rates) { Rails.configuration.x.expense_report.tax_rates.map { |rate| rate.to_f.to_s } }
    attribute(:decimal) { Rails.configuration.x.expense_report.decimal }
    attribute(:plan_price) { |sponsorship| sponsorship.plan&.price&.to_s }
    attribute(:plan_price_booth) { |sponsorship| sponsorship.plan&.price_booth&.to_s }
    attributes :booth_assigned
    attribute(:total_fee) do |sponsorship|
      plan = sponsorship.plan
      next '0' unless plan

      (sponsorship.booth_assigned? ? plan.price + plan.price_booth : plan.price).to_s
    end
  end
end
