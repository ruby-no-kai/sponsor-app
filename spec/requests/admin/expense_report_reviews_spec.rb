# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Admin Expense Report Reviews", type: :request do
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:plan) { conference.plans.first }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:, customization: true) }
  let(:staff) { FactoryBot.create(:staff) }
  let(:session_token) { FactoryBot.create(:session_token, staff:) }
  let!(:report) { ExpenseReport.create!(sponsorship:) }

  before do
    get claim_user_session_path(session_token.handle)
    report.submit!
  end

  describe "POST create (approve)" do
    it "approves the report" do
      post conference_sponsorship_expense_report_reviews_path(conference, sponsorship), params: {
        action_type: 'approve',
      }, as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['status']).to eq('approved')
    end
  end

  describe "POST create (reject)" do
    it "rejects with comment" do
      post conference_sponsorship_expense_report_reviews_path(conference, sponsorship), params: {
        action_type: 'reject',
        comment: 'Missing receipts for venue',
      }, as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['status']).to eq('rejected')
      expect(json['latest_review']['comment']).to eq('Missing receipts for venue')
    end

    it "requires comment when rejecting" do
      post conference_sponsorship_expense_report_reviews_path(conference, sponsorship), params: {
        action_type: 'reject',
        comment: nil,
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
