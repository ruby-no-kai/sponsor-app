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

  describe "POST create" do
    it "prepares a file and returns an upload session reporting to the admin path" do
      session = {url: 'https://s3.example.com/', fields: {}, max_size: 1, id: 'x'}
      allow_any_instance_of(ExpenseFile).to receive(:make_session).and_return(session) # rubocop:disable RSpec/AnyInstance

      expect do
        post conference_sponsorship_expense_files_path(conference, sponsorship), params: {filename: 'receipt.pdf', content_type: 'application/pdf'}, as: :json
      end.to change(sponsorship.expense_files, :count).by(1)

      file = sponsorship.expense_files.last
      expect(file.filename).to eq('receipt.pdf')
      expect(response.parsed_body['report_to']).to eq(conference_sponsorship_expense_file_path(conference, sponsorship, file))
    end
  end

  describe "POST initiate_update" do
    it "returns an upload session for the existing file" do
      file = ExpenseFile.prepare(conference:, sponsorship:)
      file.save!
      session = {url: 'https://s3.example.com/', fields: {}, max_size: 1, id: 'x'}
      allow_any_instance_of(ExpenseFile).to receive(:make_session).and_return(session) # rubocop:disable RSpec/AnyInstance

      post initiate_update_conference_sponsorship_expense_file_path(conference, sponsorship, file), params: {content_type: 'image/png'}, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['report_to']).to eq(conference_sponsorship_expense_file_path(conference, sponsorship, file))
    end
  end

  describe "PATCH update" do
    it "marks the file uploaded" do
      file = ExpenseFile.prepare(conference:, sponsorship:)
      file.save!
      allow_any_instance_of(ExpenseFile).to receive(:update_object_header) { |f| f } # rubocop:disable RSpec/AnyInstance

      patch conference_sponsorship_expense_file_path(conference, sponsorship, file), params: {filename: 'renamed.pdf', version_id: 'v1', extension: 'pdf'}, as: :json

      expect(response).to have_http_status(:ok)
      expect(file.reload).to have_attributes(status: 'uploaded', filename: 'renamed.pdf')
    end
  end

  describe "upload round trip" do
    let(:s3_client) do
      Aws::S3::Client.new(
        stub_responses: {
          head_object: {version_id: 'v1', last_modified: Time.zone.now, checksum_sha256: 'sum', content_type: 'application/pdf'},
        },
        region: 'ap-northeast-1',
      )
    end

    before do
      allow(Aws::STS::Client).to receive(:new).and_return(Aws::STS::Client.new(stub_responses: true, region: 'ap-northeast-1'))
      allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
    end

    it "prepares, re-initiates and records an upload end to end" do
      post conference_sponsorship_expense_files_path(conference, sponsorship), params: {filename: 'receipt.pdf', content_type: 'application/pdf'}
      expect(response).to have_http_status(:ok)
      file = ExpenseFile.find(response.parsed_body.fetch('id'))
      expect(response.parsed_body['report_to']).to eq(conference_sponsorship_expense_file_path(conference, sponsorship, file))

      post initiate_update_conference_sponsorship_expense_file_path(conference, sponsorship, file), params: {content_type: 'application/pdf'}
      expect(response).to have_http_status(:ok)

      patch conference_sponsorship_expense_file_path(conference, sponsorship, file), params: {extension: 'pdf'}
      expect(response).to have_http_status(:ok)
      expect(file.reload).to have_attributes(status: 'uploaded', version_id: 'v1')
    end
  end

  describe "GET show" do
    it "redirects to presigned S3 URL for file preview" do
      file = ExpenseFile.prepare(conference:, sponsorship:)
      file.filename = 'receipt.pdf'
      file.save!

      allow(Aws::S3::Client).to receive(:new).and_return(instance_double(Aws::S3::Client))
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
      allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
      allow(s3_client).to receive(:delete_object)

      expect do
        delete conference_sponsorship_expense_file_path(conference, sponsorship, file), as: :json
      end.to change(ExpenseFile, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end
  end
end
