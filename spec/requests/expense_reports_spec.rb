# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Expense Reports", type: :request do
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:plan) { conference.plans.first }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:, customization: true) }
  let(:session_token) { FactoryBot.create(:session_token, email: sponsorship.contact.email) }

  before do
    get claim_user_session_path(session_token.handle)
  end

  describe "POST create" do
    it "creates a draft expense report" do
      post user_conference_sponsorship_expense_report_path(conference)
      expect(response).to redirect_to(user_conference_sponsorship_expense_report_path(conference))

      expect(sponsorship.reload.expense_report).to be_present
      expect(sponsorship.expense_report.status).to eq('draft')
    end

    context "when expense report already exists with line items" do
      let!(:existing_report) { ExpenseReport.create!(sponsorship:) }
      let!(:line_item) { FactoryBot.create(:expense_line_item, expense_report: existing_report, position: 1) }

      it "preserves the existing report and its line items" do
        original_id = existing_report.id

        post user_conference_sponsorship_expense_report_path(conference)

        expect(response).to redirect_to(user_conference_sponsorship_expense_report_path(conference))
        expect(sponsorship.reload.expense_report.id).to eq(original_id)
        expect(existing_report.reload.line_items).to eq([line_item])
      end
    end

    it "rejects non-custom sponsorships" do
      sponsorship.update_column(:customization, false) # rubocop:disable Rails/SkipsModelValidations
      post user_conference_sponsorship_expense_report_path(conference), as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET show" do
    let!(:report) { ExpenseReport.create!(sponsorship:) }

    it "returns report as JSON" do
      get user_conference_sponsorship_expense_report_path(conference), as: :json
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['id']).to eq(report.id)
      expect(json['status']).to eq('draft')
    end
  end

  describe "PATCH update" do
    let!(:report) { ExpenseReport.create!(sponsorship:) }

    it "recalculates totals and returns report" do
      FactoryBot.create(:expense_line_item, expense_report: report, amount: 1000, tax_amount: 100, position: 1)
      patch user_conference_sponsorship_expense_report_path(conference), as: :json
      expect(response).to have_http_status(:ok)
      expect(report.reload.total_amount).to eq(1000)
      expect(report.total_tax_amount).to eq(100)
    end

    it "reopens a rejected report" do
      report.update!(status: 'rejected')
      patch user_conference_sponsorship_expense_report_path(conference), as: :json
      expect(response).to have_http_status(:ok)
      expect(report.reload.status).to eq('draft')
    end
  end

  describe "GET calculate" do
    before { ExpenseReport.create!(sponsorship:) }

    it "renders an ExpenseReportCalculation in .proto field names, defaults included" do
      plan.update!(price: 3_000_000, price_booth: 500_000)

      get calculate_user_conference_sponsorship_expense_report_path(conference), as: :json
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq('{"tax_rates":["0.1","0.08","0.0"],"plan_price":"3000000.0","plan_price_booth":"500000.0","total_fee":"3000000.0"}')
    end

    it "adds the booth price to the fee once a booth is assigned" do
      plan.update!(price: 3_000_000, price_booth: 500_000)
      sponsorship.update_column(:booth_assigned, true) # rubocop:disable Rails/SkipsModelValidations

      get calculate_user_conference_sponsorship_expense_report_path(conference), as: :json
      expect(response.parsed_body).to include('booth_assigned' => true, 'total_fee' => '3500000.0')
    end

    it "leaves the plan prices out and the fee zero without a plan" do
      sponsorship.update_column(:plan_id, nil) # rubocop:disable Rails/SkipsModelValidations

      get calculate_user_conference_sponsorship_expense_report_path(conference), as: :json
      expect(response.parsed_body).not_to include('plan_price', 'plan_price_booth')
      expect(response.parsed_body).to include('total_fee' => '0')
    end
  end
end
