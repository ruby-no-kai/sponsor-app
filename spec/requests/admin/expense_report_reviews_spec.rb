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
        action: 'ACTION_APPROVE',
      }, as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['status']).to eq('approved')
      expect(json['latest_review']).to include('action' => 'approve', 'comment' => nil)
    end
  end

  describe "POST create (reject)" do
    it "rejects with comment" do
      post conference_sponsorship_expense_report_reviews_path(conference, sponsorship), params: {
        action: 'ACTION_REJECT',
        comment: 'Missing receipts for venue',
      }, as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['status']).to eq('rejected')
      expect(json['latest_review']['comment']).to eq('Missing receipts for venue')
    end

    it "requires comment when rejecting" do
      post conference_sponsorship_expense_report_reviews_path(conference, sponsorship), params: {
        action: 'ACTION_REJECT',
        comment: nil,
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(report.reload.status).to eq('submitted')
    end
  end

  describe "POST create (malformed)" do
    it "answers 400 without an action" do
      post conference_sponsorship_expense_report_reviews_path(conference, sponsorship), params: {
        comment: 'Looks good',
      }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to eq('action: value is required')
      expect(report.reload.status).to eq('submitted')
    end

    it "answers 400 to ACTION_UNSPECIFIED" do
      post conference_sponsorship_expense_report_reviews_path(conference, sponsorship), params: {
        action: 'ACTION_UNSPECIFIED',
      }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to eq('action: value is required')
      expect(report.reload.status).to eq('submitted')
    end

    it "answers 400 to an action number the enum lacks" do
      post conference_sponsorship_expense_report_reviews_path(conference, sponsorship), params: {
        action: 9,
      }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to start_with('action: ')
      expect(report.reload.status).to eq('submitted')
    end

    it "answers 400 to an action the enum lacks" do
      post conference_sponsorship_expense_report_reviews_path(conference, sponsorship), params: {
        action: 'approve',
      }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to include("Unknown enumerator: 'approve'")
      expect(report.reload.status).to eq('submitted')
    end

    it "answers 400 to a field the message lacks" do
      post conference_sponsorship_expense_report_reviews_path(conference, sponsorship), params: {
        action_type: 'approve',
      }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to include('No such field: action_type')
      expect(report.reload.status).to eq('submitted')
    end
  end
end
