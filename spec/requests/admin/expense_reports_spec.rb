# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Admin Expense Reports", type: :request do
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:plan) { conference.plans.first }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:, customization: true) }
  let(:staff) { FactoryBot.create(:staff) }
  let(:session_token) { FactoryBot.create(:session_token, staff:) }

  before do
    get claim_user_session_path(session_token.handle)
  end

  describe "GET index" do
    before { sponsorship }

    it "lists custom sponsorships" do
      get conference_expense_reports_path(conference)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(sponsorship.name)
    end
  end

  describe "GET show" do
    let!(:report) { ExpenseReport.create!(sponsorship:) }

    it "returns report as JSON" do
      get conference_sponsorship_expense_report_path(conference, sponsorship), as: :json
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['id']).to eq(report.id)
    end
  end

  describe "PATCH update" do
    let!(:report) { ExpenseReport.create!(sponsorship:) }

    it "recalculates without changing status" do
      report.submit!
      FactoryBot.create(:expense_line_item, expense_report: report, amount: 500, tax_amount: 50, position: 1)

      patch conference_sponsorship_expense_report_path(conference, sponsorship), as: :json
      expect(response).to have_http_status(:ok)

      report.reload
      expect(report.status).to eq('submitted')
      expect(report.total_amount).to eq(500)
    end
  end

  describe "GET calculate" do
    before { ExpenseReport.create!(sponsorship:) }

    it "renders an ExpenseReportCalculation in .proto field names, defaults included" do
      plan.update!(price: 3_000_000, price_booth: 500_000)

      get calculate_conference_sponsorship_expense_report_path(conference, sponsorship), as: :json
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq('{"tax_rates":["0.1","0.08","0.0"],"plan_price":"3000000.0","plan_price_booth":"500000.0","total_fee":"3000000.0"}')
    end

    it "adds the booth price to the fee once a booth is assigned" do
      plan.update!(price: 3_000_000, price_booth: 500_000)
      sponsorship.update_column(:booth_assigned, true) # rubocop:disable Rails/SkipsModelValidations

      get calculate_conference_sponsorship_expense_report_path(conference, sponsorship), as: :json
      expect(response.parsed_body).to include('booth_assigned' => true, 'total_fee' => '3500000.0')
    end

    it "leaves the plan prices out and the fee zero without a plan" do
      sponsorship.update_column(:plan_id, nil) # rubocop:disable Rails/SkipsModelValidations

      get calculate_conference_sponsorship_expense_report_path(conference, sponsorship), as: :json
      expect(response.parsed_body).not_to include('plan_price', 'plan_price_booth')
      expect(response.parsed_body).to include('total_fee' => '0')
    end
  end
end
