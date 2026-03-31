# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Expense Report Submissions", type: :request do
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:plan) { conference.plans.first }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:, customization: true) }
  let(:session_token) { FactoryBot.create(:session_token, email: sponsorship.contact.email) }
  let!(:report) { ExpenseReport.create!(sponsorship:) }

  before do
    get claim_user_session_path(session_token.handle)
  end

  describe "POST create (submit)" do
    it "submits the report" do
      post user_conference_sponsorship_expense_report_submission_path(conference), as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['status']).to eq('submitted')
      expect(json['revision']).to eq(1)
    end

    it "fires Slack notification" do
      allow(SlackWebhookJob).to receive(:perform_later).and_call_original
      post user_conference_sponsorship_expense_report_submission_path(conference), as: :json
      expect(SlackWebhookJob).to have_received(:perform_later).with(
        hash_including(:text),
        hook_name: :feed,
      )
    end

    it "rejects submission of non-draft report" do
      report.submit!

      expect do
        post user_conference_sponsorship_expense_report_submission_path(conference), as: :json
      end.to raise_error(RuntimeError, /Cannot submit/)
    end
  end

  describe "DELETE destroy (withdraw)" do
    before { report.submit! }

    it "withdraws the submission" do
      delete user_conference_sponsorship_expense_report_submission_path(conference), as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['status']).to eq('draft')
    end

    it "rejects withdrawal of non-submitted report" do
      report.withdraw_submission!

      expect do
        delete user_conference_sponsorship_expense_report_submission_path(conference), as: :json
      end.to raise_error(RuntimeError, /Cannot withdraw/)
    end
  end
end
