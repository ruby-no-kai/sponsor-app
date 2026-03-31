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

    it "returns tax rates and fee breakdown" do
      get calculate_user_conference_sponsorship_expense_report_path(conference), as: :json
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['tax_rates']).to be_an(Array)
      expect(json['plan_price']).to be_present
      expect(json).to have_key('booth_assigned')
      expect(json).to have_key('total_fee')
    end
  end
end
