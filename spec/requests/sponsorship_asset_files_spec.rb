# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Sponsorship asset files", type: :request do
  let(:conference) { FactoryBot.create(:conference, :full, application_opens_at: 1.day.ago) }
  let(:staff) { FactoryBot.create(:staff) }
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
  end

  def sign_in_staff
    get claim_user_session_path(FactoryBot.create(:session_token, staff:).handle)
  end

  def upload
    post user_conference_sponsorship_asset_files_path(conference), params: {content_type: 'image/png'}
    SponsorshipAssetFile.find(response.parsed_body.fetch('id'))
  end

  describe "POST create" do
    it "prepares an upload session and remembers the file" do
      asset_file = upload

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['report_to']).to eq(user_conference_sponsorship_asset_file_path(conference, asset_file))
      expect(asset_file.prefix).to eq("c-#{conference.id}/")
      expect(session[:asset_file_ids]).to eq([asset_file.id])
    end

    it "is not found for an unknown conference" do
      post user_conference_sponsorship_asset_files_path(conference_slug: 'unknown'), params: {content_type: 'image/png'}
      expect(response).to have_http_status(:not_found)
    end

    it "is not found for staff on an unknown conference" do
      sign_in_staff
      post user_conference_sponsorship_asset_files_path(conference_slug: 'unknown'), params: {content_type: 'image/png'}
      expect(response).to have_http_status(:not_found)
    end

    context "when amendment is closed" do
      before { conference.update!(amendment_closes_at: 1.hour.ago) }

      it "is forbidden" do
        post user_conference_sponsorship_asset_files_path(conference), params: {content_type: 'image/png'}
        expect(response).to have_http_status(:forbidden)
      end

      it "is allowed for staff" do
        sign_in_staff
        upload
        expect(response).to have_http_status(:ok)
      end
    end

    it "is forbidden once the sponsorship has an asset file" do
      sponsorship = FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first)
      get claim_user_session_path(FactoryBot.create(:session_token, email: sponsorship.contact.email).handle)

      post user_conference_sponsorship_asset_files_path(conference), params: {content_type: 'image/png'}
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST initiate_update" do
    it "refreshes the upload session of a file in the session" do
      asset_file = upload

      post initiate_update_user_conference_sponsorship_asset_file_path(conference, asset_file), params: {content_type: 'image/jpeg'}
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['id']).to eq(asset_file.id.to_s)
    end

    it "is not found for staff on an unknown conference" do
      sign_in_staff
      asset_file = upload

      post initiate_update_user_conference_sponsorship_asset_file_path(conference_slug: 'unknown', id: asset_file), params: {content_type: 'image/jpeg'}
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH update" do
    it "records the uploaded object" do
      asset_file = upload

      patch user_conference_sponsorship_asset_file_path(conference, asset_file), params: {extension: 'PNG'}
      expect(response).to have_http_status(:ok)
      expect(asset_file.reload.extension).to eq('png')
      expect(asset_file.version_id).to eq('v1')
    end
  end

  describe "GET show" do
    it "redirects to the object" do
      asset_file = upload

      get user_conference_sponsorship_asset_file_path(conference, asset_file)
      expect(response).to have_http_status(:found)
      expect(response.location).to include(asset_file.object_key)
    end

    it "is not found for a file outside the session" do
      asset_file = SponsorshipAssetFile.prepare(conference:).tap(&:save!)

      get user_conference_sponsorship_asset_file_path(conference, asset_file)
      expect(response).to have_http_status(:not_found)
    end
  end
end
