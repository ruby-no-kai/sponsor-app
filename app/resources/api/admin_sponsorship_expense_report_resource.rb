# typed: strict
# frozen_string_literal: true

module Api
  class AdminSponsorshipExpenseReportResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::AdminSponsorship::ExpenseReport do
      attribute(:status) { |report| :"STATUS_#{report.status.upcase}" }
      attribute(:total_amount) { |report| report.total_amount.to_s }
      attribute(:total_tax_amount) { |report| report.total_tax_amount.to_s }
    end
  end
end
