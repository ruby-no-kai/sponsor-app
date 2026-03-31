# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Admin Expense Files", type: :request do
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:plan) { conference.plans.first }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:, customization: true) }
  let(:staff) { FactoryBot.create(:staff) }
  let(:session_token) { FactoryBot.create(:session_token, staff:) }

  before do
    get claim_user_session_path(session_token.handle)
  end

  describe "GET show" do
    it "redirects to presigned S3 URL for file preview" do
      file = ExpenseFile.prepare(conference:, sponsorship:)
      file.filename = 'receipt.pdf'
      file.save!

      presigner = instance_double(Aws::S3::Presigner)
      allow(Aws::S3::Presigner).to receive(:new).and_return(presigner)
      allow(presigner).to receive(:presigned_url).and_return("https://s3.example.com/presigned")

      get conference_sponsorship_expense_file_path(conference, sponsorship, file)
      expect(response).to redirect_to("https://s3.example.com/presigned")
    end
  end

  describe "DELETE destroy" do
    it "hard-deletes the file" do
      file = ExpenseFile.prepare(conference:, sponsorship:)
      file.filename = 'receipt.pdf'
      file.save!

      s3_client = instance_double(Aws::S3::Client)
      allow(file).to receive(:s3_client).and_return(s3_client)
      allow(s3_client).to receive(:delete_object)

      # Use find to get the same instance Rails will load
      allow(ExpenseFile).to receive(:find).and_return(file)

      expect do
        delete conference_sponsorship_expense_file_path(conference, sponsorship, file), as: :json
      end.to change(ExpenseFile, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end
  end
end
