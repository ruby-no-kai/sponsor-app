# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Sponsor event asset files", type: :request do
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first, accepted_at: Time.current) }
  let(:s3_client) do
    Aws::S3::Client.new(
      stub_responses: {
        head_object: {version_id: 'v1', last_modified: Time.zone.now, checksum_sha256: 'sum', content_type: 'image/png'},
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
    post user_conference_event_asset_files_path(conference), params: {content_type: 'image/png'}
    SponsorEventAssetFile.find(response.parsed_body.fetch('id'))
  end

  it "prepares an upload session" do
    asset_file = upload

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['report_to']).to eq(user_conference_event_asset_file_path(conference, asset_file))
    expect(asset_file.sponsorship).to eq(sponsorship)
    expect(asset_file.prefix).to eq("c-#{conference.id}/events/s-#{sponsorship.id}/")
  end

  it "refreshes the upload session" do
    asset_file = upload

    post initiate_update_user_conference_event_asset_file_path(conference, asset_file), params: {content_type: 'image/jpeg'}
    expect(response).to have_http_status(:ok)
    expect(asset_file.reload.content_type).to eq('image/png')
  end

  it "records the uploaded object" do
    asset_file = upload

    patch user_conference_event_asset_file_path(conference, asset_file), params: {extension: 'png'}
    expect(response).to have_http_status(:ok)
    expect(asset_file.reload.version_id).to eq('v1')
  end

  it "redirects to the object" do
    asset_file = upload

    get user_conference_event_asset_file_path(conference, asset_file)
    expect(response.location).to include(asset_file.object_key)
  end

  it "is forbidden before the sponsorship is accepted" do
    sponsorship.update!(accepted_at: nil)
    post user_conference_event_asset_files_path(conference), params: {content_type: 'image/png'}
    expect(response).to have_http_status(:forbidden)
  end
end
