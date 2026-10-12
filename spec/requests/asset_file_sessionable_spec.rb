# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "AssetFileSessionable in a controller without its own asset_file reader", type: :request do
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first, customization: true) }
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
    get claim_user_session_path(FactoryBot.create(:session_token, staff: FactoryBot.create(:staff)).handle)
  end

  it "prepares an upload session and records the upload" do
    post conference_sponsorship_expense_files_path(conference, sponsorship), params: {filename: 'receipt.pdf', content_type: 'application/pdf'}
    expect(response).to have_http_status(:ok)
    file = ExpenseFile.find(response.parsed_body.fetch('id'))
    expect(response.parsed_body['report_to']).to eq(conference_sponsorship_expense_file_path(conference, sponsorship, file))

    post initiate_update_conference_sponsorship_expense_file_path(conference, sponsorship, file), params: {content_type: 'application/pdf'}
    expect(response).to have_http_status(:ok)

    patch conference_sponsorship_expense_file_path(conference, sponsorship, file), params: {extension: 'pdf'}
    expect(response).to have_http_status(:ok)
    expect(file.reload.status).to eq('uploaded')
    expect(file.version_id).to eq('v1')
  end
end
