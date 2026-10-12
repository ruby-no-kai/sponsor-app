# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Expense Files", type: :request do
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:plan) { conference.plans.first }
  let(:customization) { true }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:, customization:) }
  let(:session_token) { FactoryBot.create(:session_token, email: sponsorship.contact.email) }

  before do
    get claim_user_session_path(session_token.handle)
  end

  describe "POST create" do
    before do
      allow(ExpenseFile).to receive(:prepare).and_wrap_original do |original, **kwargs|
        original.call(**kwargs).tap do |file|
          allow(file).to receive(:upload_url_and_fields).and_return({url: 'https://s3.example.invalid/', fields: {}})
        end
      end
    end

    it "creates a file and returns an upload session" do
      expect do
        post user_conference_expense_files_path(conference), params: {filename: 'receipt.pdf', content_type: 'application/pdf'}, as: :json
      end.to change(ExpenseFile, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['url']).to eq('https://s3.example.invalid/')
    end

    context "with a non-custom sponsorship" do
      let(:customization) { false }

      it "rejects without creating a file" do
        expect do
          post user_conference_expense_files_path(conference), params: {filename: 'receipt.pdf', content_type: 'application/pdf'}, as: :json
        end.not_to change(ExpenseFile, :count)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "POST initiate_update" do
    let(:customization) { false }
    let!(:file) { FactoryBot.create(:expense_file, sponsorship:) }

    it "rejects a non-custom sponsorship" do
      post initiate_update_user_conference_expense_file_path(conference, file), as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end
end
