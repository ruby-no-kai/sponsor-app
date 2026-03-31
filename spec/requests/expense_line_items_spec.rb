# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Expense Line Items", type: :request do
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:plan) { conference.plans.first }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:, customization: true) }
  let(:session_token) { FactoryBot.create(:session_token, email: sponsorship.contact.email) }
  let!(:report) { ExpenseReport.create!(sponsorship:) }

  before do
    get claim_user_session_path(session_token.handle)
  end

  describe "POST create" do
    it "creates a line item and recalculates totals" do
      post user_conference_sponsorship_expense_report_line_items_path(conference), params: {
        expense_line_item: {title: 'Venue rental', amount: 5000, tax_rate: '0.1', tax_amount: 0},
      }, as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['line_items'].size).to eq(1)
      expect(json['total_amount'].to_d).to eq(5000)
      expect(json['total_tax_amount'].to_d).to eq(500)
    end

    it "creates a line item with pre-linked files" do
      file = ExpenseFile.prepare(conference:, sponsorship:)
      file.status = 'uploaded'
      file.save!

      post user_conference_sponsorship_expense_report_line_items_path(conference), params: {
        expense_line_item: {title: 'Receipt', amount: 100, tax_amount: 0, file_ids: [file.id]},
      }, as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      created_item = json['line_items'].last
      expect(created_item['file_ids']).to eq([file.id])
    end
  end

  describe "PATCH update" do
    let!(:item) { FactoryBot.create(:expense_line_item, expense_report: report, amount: 1000, tax_amount: 100, position: 1) }

    it "updates the line item" do
      patch user_conference_sponsorship_expense_report_line_item_path(conference, item), params: {
        expense_line_item: {title: 'Updated title', amount: 2000},
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(item.reload.title).to eq('Updated title')
    end

    it "auto-reopens a rejected report" do
      report.update!(status: 'rejected')
      patch user_conference_sponsorship_expense_report_line_item_path(conference, item), params: {
        expense_line_item: {title: 'Edited'},
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(report.reload.status).to eq('draft')
    end

    it "syncs file attachments" do
      file = ExpenseFile.prepare(conference:, sponsorship:)
      file.save!

      patch user_conference_sponsorship_expense_report_line_item_path(conference, item), params: {
        expense_line_item: {title: item.title, file_ids: [file.id]},
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(item.reload.expense_file_ids).to eq([file.id])
    end
  end

  describe "DELETE destroy" do
    let!(:item) { FactoryBot.create(:expense_line_item, expense_report: report, amount: 1000, tax_amount: 100, position: 1) }

    it "destroys the line item and recalculates" do
      delete user_conference_sponsorship_expense_report_line_item_path(conference, item), as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['line_items']).to be_empty
      expect(json['total_amount'].to_d).to eq(0)
    end
  end
end
