# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Expense files", type: :request do
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:customization) { true }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first, customization:) }
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
    get claim_user_session_path(FactoryBot.create(:session_token, email: sponsorship.contact.email).handle)
  end

  def upload
    post user_conference_expense_files_path(conference), params: {filename: 'receipt.pdf', content_type: 'application/pdf'}
    ExpenseFile.find(response.parsed_body.fetch('file_id'))
  end

  it "prepares an upload session" do
    file = upload

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['report_to']).to eq(user_conference_expense_file_path(conference, file))
    expect(response.parsed_body.keys).to eq(%w(file_id url fields max_size report_to id))
    expect(response.parsed_body).to include('file_id' => file.id.to_s, 'id' => file.id.to_s, 'max_size' => ExpenseFile::MAX_FILE_SIZE.to_s)
    expect(response.parsed_body.fetch('fields')).to include('key' => file.object_key, 'Content-Type' => 'application/pdf')
    expect(file.filename).to eq('receipt.pdf')
    expect(file.prefix).to eq("c-#{conference.id}/expenses/s-#{sponsorship.id}/")
  end

  it "marks the file uploaded" do
    file = upload

    patch user_conference_expense_file_path(conference, file), params: {extension: 'pdf'}
    expect(response).to have_http_status(:ok)
    expect(file.reload.status).to eq('uploaded')
  end

  it "refreshes the upload session" do
    file = upload

    post initiate_update_user_conference_expense_file_path(conference, file), params: {content_type: 'image/png'}
    expect(response).to have_http_status(:ok)
  end

  it "redirects to the object inline" do
    file = upload

    get user_conference_expense_file_path(conference, file)
    expect(response.location).to include(file.object_key)
    expect(response.location).to include('inline')
  end

  it "deletes the file" do
    file = upload

    expect do
      delete user_conference_expense_file_path(conference, file), as: :json
    end.to change(ExpenseFile, :count).by(-1)
  end

  it "is not found for another sponsorship's file" do
    other = FactoryBot.create(:expense_file, sponsorship: FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first))

    get user_conference_expense_file_path(conference, other)
    expect(response).to have_http_status(:not_found)
  end

  context "with a non-custom sponsorship" do
    let(:customization) { false }

    it "rejects creating a file" do
      expect do
        post user_conference_expense_files_path(conference), params: {filename: 'receipt.pdf', content_type: 'application/pdf'}
      end.not_to change(ExpenseFile, :count)

      expect(response).to have_http_status(:forbidden)
    end

    it "rejects refreshing an upload session" do
      file = FactoryBot.create(:expense_file, sponsorship:)

      post initiate_update_user_conference_expense_file_path(conference, file), params: {content_type: 'image/png'}
      expect(response).to have_http_status(:forbidden)
    end
  end
end
