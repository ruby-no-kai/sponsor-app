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
        expense_line_item: {title: 'Venue rental', amount: '5000', tax_rate: '0.1', tax_amount: '0'},
        field_mask: %w[title amount tax_rate tax_amount],
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
        expense_line_item: {title: 'Receipt', amount: '100', tax_amount: '0', file_ids: [file.id.to_s]},
        field_mask: %w[title amount tax_amount file_ids],
      }, as: :json

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      created_item = json['line_items'].last
      expect(created_item['file_ids']).to eq([file.id])
    end

    it "leaves the fields the field_mask does not name at their defaults" do
      post user_conference_sponsorship_expense_report_line_items_path(conference), params: {
        expense_line_item: {title: 'Venue rental', notes: 'Hall A', amount: '5000', preliminal: true},
        field_mask: %w[title],
      }, as: :json

      expect(response).to have_http_status(:ok)
      item = report.line_items.sole
      expect([item.title, item.notes, item.amount, item.preliminal]).to eq(['Venue rental', nil, 0, false])
    end

    it "adds the line item last whatever position it names" do
      FactoryBot.create(:expense_line_item, expense_report: report, position: 1)

      post user_conference_sponsorship_expense_report_line_items_path(conference), params: {
        expense_line_item: {title: 'Venue rental', position: 1},
        field_mask: %w[title position],
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(report.line_items.order(:position).pluck(:title)).to eq(['Test expense', 'Venue rental'])
    end

    it "answers 400 to a field of the wrong type" do
      post user_conference_sponsorship_expense_report_line_items_path(conference), params: {
        expense_line_item: {title: 'Venue rental', amount: 5000},
        field_mask: %w[title amount],
      }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to include('Expected string')
      expect(report.line_items).to be_empty
    end

    it "answers 400 to a field the message lacks" do
      post user_conference_sponsorship_expense_report_line_items_path(conference), params: {
        expense_line_item: {title: 'Venue rental', currency: 'JPY'},
        field_mask: %w[title],
      }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to include('No such field: currency')
      expect(report.line_items).to be_empty
    end

    it "creates from a body without field_mask, writing the fields it has" do
      file = ExpenseFile.prepare(conference:, sponsorship:)
      file.save!

      post user_conference_sponsorship_expense_report_line_items_path(conference), params: {
        expense_line_item: {title: 'Receipt', amount: '0', tax_amount: '0', file_ids: [file.id]},
      }, as: :json

      expect(response).to have_http_status(:ok)
      item = report.line_items.sole
      expect([item.title, item.amount, item.expense_file_ids]).to eq(['Receipt', 0, [file.id]])
    end

    it "answers 400 to a body without field_mask naming no field" do
      post user_conference_sponsorship_expense_report_line_items_path(conference), params: {
        expense_line_item: {},
      }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to eq('field_mask names no field')
      expect(report.line_items).to be_empty
    end

    it "answers 400 to a body without field_mask repeating a key" do
      post user_conference_sponsorship_expense_report_line_items_path(conference),
        params: '{"expense_line_item": {"title": "Venue", "title": "Hall"}}', headers: {'CONTENT_TYPE' => 'application/json'}

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to include('duplicate key')
      expect(report.line_items).to be_empty
    end

    it "answers 400 to a field name that is not UTF-8" do
      post user_conference_sponsorship_expense_report_line_items_path(conference),
        params: "{\"\xff\": 1}".b, headers: {'CONTENT_TYPE' => 'application/json'}

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to include("No such field: \uFFFD")
      expect(report.line_items).to be_empty
    end

    it "decodes the body when the query string carries _protobuf" do
      post "#{user_conference_sponsorship_expense_report_line_items_path(conference)}?_protobuf=x", params: {
        expense_line_item: {title: 'Venue rental', amount: '5000', tax_amount: '0'},
        field_mask: %w[title amount tax_amount],
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(report.line_items.sole.title).to eq('Venue rental')
    end

    it "answers 400 to a body that is not JSON" do
      post "#{user_conference_sponsorship_expense_report_line_items_path(conference)}?_protobuf=x",
        params: 'title=Venue', headers: {'CONTENT_TYPE' => 'application/json'}

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to have_key('error')
      expect(report.line_items).to be_empty
    end

    it "answers 400 to a field_mask naming a field the input lacks" do
      post user_conference_sponsorship_expense_report_line_items_path(conference), params: {
        expense_line_item: {title: 'Venue rental'},
        field_mask: %w[title id],
      }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to start_with('field_mask[1]: ')
      expect(report.line_items).to be_empty
    end

    it "answers 400 to a field_mask naming a field twice" do
      post user_conference_sponsorship_expense_report_line_items_path(conference), params: {
        expense_line_item: {title: 'Venue rental'},
        field_mask: %w[title title],
      }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to start_with('field_mask: ')
      expect(report.line_items).to be_empty
    end

    it "answers 400 naming each field a value the field_mask names breaks the rules of" do
      post user_conference_sponsorship_expense_report_line_items_path(conference), params: {
        expense_line_item: {title: '  ', amount: '12.345', tax_rate: '10%', tax_amount: '0', position: 0, file_ids: %w[7 7]},
        field_mask: %w[title amount tax_rate tax_amount position file_ids],
      }, as: :json

      expect(response).to have_http_status(:bad_request)
      error = response.parsed_body['error']
      expect(error).to include('title: value must not be blank')
      expect(error).to include('amount: must be an amount such as 1000 or 1000.50')
      expect(error).to include('tax_rate: must be a rate such as 0.1 or 0.08')
      expect(error).to include('position: ')
      expect(error).to include('file_ids: ')
      expect(error).not_to include('tax_amount')
      expect(report.line_items).to be_empty
    end

    it "does not judge a field the field_mask leaves out" do
      post user_conference_sponsorship_expense_report_line_items_path(conference), params: {
        expense_line_item: {title: 'Venue rental', amount: 'many'},
        field_mask: %w[title],
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(report.line_items.sole.title).to eq('Venue rental')
    end
  end

  describe "PATCH update" do
    let!(:item) { FactoryBot.create(:expense_line_item, expense_report: report, amount: 1000, tax_amount: 100, position: 1) }

    it "updates the line item" do
      patch user_conference_sponsorship_expense_report_line_item_path(conference, item), params: {
        expense_line_item: {title: 'Updated title', amount: '2000'},
        field_mask: %w[title amount],
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect([item.reload.title, item.amount]).to eq(['Updated title', 2000])
    end

    it "leaves the fields the field_mask does not name as they are" do
      file = ExpenseFile.prepare(conference:, sponsorship:)
      file.save!
      item.update!(notes: 'Hall A', preliminal: true)
      item.expense_line_item_files.create!(expense_file: file)

      patch user_conference_sponsorship_expense_report_line_item_path(conference, item), params: {
        expense_line_item: {title: 'Updated title', notes: 'Hall B', file_ids: []},
        field_mask: %w[title],
      }, as: :json

      expect(response).to have_http_status(:ok)
      item.reload
      expect([item.title, item.notes, item.tax_rate, item.preliminal]).to eq(['Updated title', 'Hall A', 0.1, true])
      expect(item.expense_file_ids).to eq([file.id])
    end

    it "clears the fields the field_mask names but expense_line_item sets to null" do
      item.update!(notes: 'Hall A', preliminal: true)

      patch user_conference_sponsorship_expense_report_line_item_path(conference, item), params: {
        expense_line_item: {notes: nil, tax_rate: nil, preliminal: nil},
        field_mask: %w[notes tax_rate preliminal],
      }, as: :json

      expect(response).to have_http_status(:ok)
      item.reload
      expect([item.notes, item.tax_rate, item.preliminal, item.tax_amount]).to eq([nil, nil, false, 100])
    end

    it "keeps the position the field_mask names but expense_line_item leaves unset" do
      patch user_conference_sponsorship_expense_report_line_item_path(conference, item), params: {
        expense_line_item: {title: 'Edited'},
        field_mask: %w[title position],
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(item.reload.position).to eq(1)
    end

    it "refuses a title the field_mask names but expense_line_item leaves unset" do
      patch user_conference_sponsorship_expense_report_line_item_path(conference, item), params: {
        expense_line_item: {},
        field_mask: %w[title],
      }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to start_with('title: ')
      expect(item.reload.title).to eq('Test expense')
    end

    it "answers 400 naming the field a value the field_mask names breaks the rules of" do
      patch user_conference_sponsorship_expense_report_line_item_path(conference, item), params: {
        expense_line_item: {title: 'Edited', amount: '-1'},
        field_mask: %w[title amount],
      }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to eq('amount: must be an amount such as 1000 or 1000.50')
      expect(item.reload.title).to eq('Test expense')
    end

    it "does not judge the fields the field_mask leaves out, which a patch of one field leaves unset" do
      patch user_conference_sponsorship_expense_report_line_item_path(conference, item), params: {
        expense_line_item: {notes: 'Hall A'},
        field_mask: %w[notes],
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(item.reload.notes).to eq('Hall A')
      expect(item.title).to eq('Test expense')
    end

    it "does not judge the fields a body without field_mask leaves out" do
      patch user_conference_sponsorship_expense_report_line_item_path(conference, item), params: {
        expense_line_item: {notes: 'Hall A'},
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(item.reload.notes).to eq('Hall A')
    end

    it "auto-reopens a rejected report" do
      report.update!(status: 'rejected')
      patch user_conference_sponsorship_expense_report_line_item_path(conference, item), params: {
        expense_line_item: {title: 'Edited'},
        field_mask: %w[title],
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(report.reload.status).to eq('draft')
    end

    it "syncs file attachments" do
      file = ExpenseFile.prepare(conference:, sponsorship:)
      file.save!

      patch user_conference_sponsorship_expense_report_line_item_path(conference, item), params: {
        expense_line_item: {title: item.title, file_ids: [file.id.to_s]},
        field_mask: %w[title file_ids],
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(item.reload.expense_file_ids).to eq([file.id])
    end

    it "detaches every file when the field_mask names file_ids and expense_line_item lists none" do
      file = ExpenseFile.prepare(conference:, sponsorship:)
      file.save!
      item.expense_line_item_files.create!(expense_file: file)

      patch user_conference_sponsorship_expense_report_line_item_path(conference, item), params: {
        expense_line_item: {file_ids: []},
        field_mask: %w[file_ids],
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(item.reload.expense_file_ids).to be_empty
    end

    it "answers 400 to a field of the wrong type" do
      patch user_conference_sponsorship_expense_report_line_item_path(conference, item), params: {
        expense_line_item: {preliminal: 'yes'},
        field_mask: %w[preliminal],
      }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to include('Expected true or false')
    end

    it "reads a body without field_mask as a merge patch, where null clears" do
      file = ExpenseFile.prepare(conference:, sponsorship:)
      file.save!
      item.update!(notes: 'Hall A', preliminal: true)
      item.expense_line_item_files.create!(expense_file: file)

      patch user_conference_sponsorship_expense_report_line_item_path(conference, item), params: {
        expense_line_item: {title: 'Edited', notes: nil, tax_rate: nil, preliminal: false, file_ids: []},
      }, as: :json

      expect(response).to have_http_status(:ok)
      item.reload
      expect([item.title, item.notes, item.tax_rate, item.preliminal, item.amount]).to eq(['Edited', nil, nil, false, 1000])
      expect(item.expense_file_ids).to be_empty
    end

    it "leaves the fields a body without field_mask lacks as they are" do
      file = ExpenseFile.prepare(conference:, sponsorship:)
      file.save!
      item.update!(notes: 'Hall A')
      item.expense_line_item_files.create!(expense_file: file)

      patch user_conference_sponsorship_expense_report_line_item_path(conference, item), params: {
        expense_line_item: {title: 'Edited'},
      }, as: :json

      expect(response).to have_http_status(:ok)
      item.reload
      expect([item.title, item.notes, item.tax_rate]).to eq(['Edited', 'Hall A', 0.1])
      expect(item.expense_file_ids).to eq([file.id])
    end

    it "answers 400 to a field_mask in lowerCamelCase" do
      patch user_conference_sponsorship_expense_report_line_item_path(conference, item), params: {
        expense_line_item: {tax_rate: '0.08'},
        field_mask: %w[taxRate],
      }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to start_with('field_mask[0]: ')
      expect(item.reload.tax_rate).to eq(0.1)
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

    it "answers 400 to a body that is not JSON" do
      delete user_conference_sponsorship_expense_report_line_item_path(conference, item),
        params: "{\"notes\": \xff}".b, headers: {'CONTENT_TYPE' => 'application/json'}

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body['error']).to be_present
      expect(report.line_items).to eq([item])
    end
  end
end
