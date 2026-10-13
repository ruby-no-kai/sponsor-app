# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Admin Expense Line Items", type: :request do
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:plan) { conference.plans.first }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:, customization: true) }
  let(:staff) { FactoryBot.create(:staff) }
  let(:session_token) { FactoryBot.create(:session_token, staff:) }
  let!(:report) { ExpenseReport.create!(sponsorship:) }

  before do
    get claim_user_session_path(session_token.handle)
  end

  describe "POST create" do
    it "creates a line item with linked files and recalculates totals" do
      file = ExpenseFile.prepare(conference:, sponsorship:)
      file.save!

      post conference_sponsorship_expense_report_line_items_path(conference, sponsorship), params: {
        expense_line_item: {title: 'Venue rental', amount: '5000', tax_rate: '0.1', tax_amount: '0', file_ids: [file.id]},
        field_mask: %w[title amount tax_rate tax_amount file_ids],
      }, as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['line_items'].map { |i| i['file_ids'] }).to eq([[file.id]])
      expect(json['total_amount'].to_d).to eq(5000)
    end

    it "answers 400 to a field of the wrong type" do
      post conference_sponsorship_expense_report_line_items_path(conference, sponsorship), params: {
        expense_line_item: {title: 'Venue rental', file_ids: ['receipt.pdf']},
        field_mask: %w[title file_ids],
      }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to be_present
      expect(report.line_items).to be_empty
    end
  end

  describe "POST create rules" do
    it "answers 400 naming the field whose value breaks a rule" do
      post conference_sponsorship_expense_report_line_items_path(conference, sponsorship), params: {
        expense_line_item: {title: 'Venue rental', amount: '5,000'},
        field_mask: %w[title amount],
      }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to eq('amount: must be an amount such as 1000 or 1000.50')
      expect(report.line_items).to be_empty
    end
  end

  describe "PATCH update" do
    let!(:first) { FactoryBot.create(:expense_line_item, expense_report: report, title: 'First', position: 1) }
    let!(:second) { FactoryBot.create(:expense_line_item, expense_report: report, title: 'Second', position: 2) }

    it "moves the line item and renumbers the others" do
      patch conference_sponsorship_expense_report_line_item_path(conference, sponsorship, second), params: {
        expense_line_item: {position: 1},
        field_mask: %w[position],
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['line_items'].map { |i| i['title'] }).to eq(%w(Second First))
      expect([first.reload.position, second.reload.position]).to eq([2, 1])
    end

    it "moves the line item on a body without field_mask" do
      patch conference_sponsorship_expense_report_line_item_path(conference, sponsorship, second), params: {
        expense_line_item: {position: 1},
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect([first.reload.position, second.reload.position]).to eq([2, 1])
    end

    it "clears the notes the field_mask names but expense_line_item leaves unset" do
      first.update!(notes: 'Hall A')

      patch conference_sponsorship_expense_report_line_item_path(conference, sponsorship, first), params: {
        expense_line_item: {title: 'First'},
        field_mask: %w[title notes],
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(first.reload.notes).to be_nil
    end

    it "answers 400 naming the field whose value breaks a rule" do
      patch conference_sponsorship_expense_report_line_item_path(conference, sponsorship, second), params: {
        expense_line_item: {position: 0},
        field_mask: %w[position],
      }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to start_with('position: ')
      expect(second.reload.position).to eq(2)
    end

    it "answers 400 to a field_mask naming a field the input lacks" do
      patch conference_sponsorship_expense_report_line_item_path(conference, sponsorship, second), params: {
        expense_line_item: {position: 1},
        field_mask: %w[position id],
      }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to start_with('field_mask[1]: ')
    end

    it "answers 400 to a field the message lacks" do
      patch conference_sponsorship_expense_report_line_item_path(conference, sponsorship, second), params: {
        expense_line_item: {position: 1},
        field_mask: %w[position],
        expense_line_item_id: second.id,
      }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to include('No such field: expense_line_item_id')
      expect(second.reload.position).to eq(2)
    end
  end

  describe "DELETE destroy" do
    let!(:item) { FactoryBot.create(:expense_line_item, expense_report: report, amount: 1000, tax_amount: 100, position: 1) }

    it "removes the line item and recalculates totals" do
      delete conference_sponsorship_expense_report_line_item_path(conference, sponsorship, item), as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['line_items']).to be_empty
      expect(report.reload.total_amount).to eq(0)
    end
  end
end
