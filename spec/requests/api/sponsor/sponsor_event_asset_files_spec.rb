# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SponsorService event image uploads', type: :request do
  let(:create_upload) { connect_method('SponsorService', 'CreateSponsorEventAssetUpload') }
  let(:initiate_update) { connect_method('SponsorService', 'InitiateSponsorEventAssetUpdate') }
  let(:complete_upload) { connect_method('SponsorService', 'CompleteSponsorEventAssetUpload') }

  let(:conference) { FactoryBot.create(:conference, :full, event_submission_starts_at: 1.day.ago) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first, accepted_at: 1.hour.ago) }
  let(:head_object) { {version_id: 'v2', last_modified: Time.zone.now, checksum_sha256: 'sum', content_type: 'image/png'} }
  let(:s3_client) { Aws::S3::Client.new(stub_responses: {head_object:}, region: 'ap-northeast-1') }

  before do
    allow(Aws::STS::Client).to receive(:new).and_return(Aws::STS::Client.new(stub_responses: true, region: 'ap-northeast-1'))
    allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
  end

  def create_request(slug = conference.slug, content_type: 'image/png')
    Rk::SponsorApp::SponsorServiceCreateSponsorEventAssetUploadRequest.new(conference_slug: slug, content_type:)
  end

  def initiate_request(asset_file, **fields)
    Rk::SponsorApp::SponsorServiceInitiateSponsorEventAssetUpdateRequest.new(
      conference_slug: conference.slug, asset_file_id: asset_file.id, **fields,
    )
  end

  def complete_request(asset_file, **fields)
    Rk::SponsorApp::SponsorServiceCompleteSponsorEventAssetUploadRequest.new(
      conference_slug: conference.slug, asset_file_id: asset_file.id, **fields,
    )
  end

  def image(owner = sponsorship, **attributes)
    SponsorEventAssetFile.prepare(conference:, sponsorship: owner).tap { it.update!(extension: 'png', **attributes) }
  end

  def other_sponsorship = FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first)

  it 'answers unauthenticated without a sponsor session' do
    expect(connect_call(create_upload, create_request)).to have_attributes(code: 'unauthenticated')
  end

  context 'with a sponsor session' do
    before { sign_in_sponsor(sponsorship.contact.email) }

    shared_examples 'an upload RPC' do
      it 'answers failed_precondition while the sponsorship is not accepted' do
        sponsorship.update!(accepted_at: nil)

        expect(call).to have_attributes(code: 'failed_precondition', message: I18n.t('sponsor_events.sponsorship_not_accepted'))
      end

      it 'answers failed_precondition while event submission is not open' do
        conference.update!(event_submission_starts_at: 1.day.from_now)

        expect(call).to have_attributes(code: 'failed_precondition', message: I18n.t('sponsor_events.event_submission_not_open'))
      end
    end

    describe 'CreateSponsorEventAssetUpload' do
      let(:call) { connect_call(create_upload, create_request) }

      it_behaves_like 'an upload RPC'

      it "hands out a presigned POST for a file of the sponsorship's own" do
        result = connect_call(create_upload, create_request).upload

        asset_file = SponsorEventAssetFile.find(result.file_id)
        expect(asset_file).to have_attributes(sponsorship:, sponsor_event: nil, content_type: 'image/png', prefix: "c-#{conference.id}/events/s-#{sponsorship.id}/")
        expect(result.fields.to_h).to include('key' => asset_file.object_key, 'Content-Type' => 'image/png')
        expect(result.max_size).to eq(SponsorEventAssetFile::MAX_FILE_SIZE)
      end

      it 'leaves the content type open when the browser cannot tell' do
        result = connect_call(create_upload, create_request.tap { it.clear_content_type }).upload

        expect(result.fields.to_h).not_to have_key('Content-Type')
      end

      it 'refuses a GIF before anything is stored' do
        error = connect_call(create_upload, create_request(content_type: 'image/gif'))

        expect(violations_of(error)).to eq([['contentType', 'STRING_IN']])
        expect(SponsorEventAssetFile.count).to eq(0)
      end

      it 'answers not_found for a conference the contact does not sponsor' do
        expect(connect_call(create_upload, create_request(FactoryBot.create(:conference, :full).slug))).to have_attributes(code: 'not_found')
      end
    end

    describe 'InitiateSponsorEventAssetUpdate' do
      let(:asset_file) { image }
      let(:call) { connect_call(initiate_update, initiate_request(asset_file)) }

      it_behaves_like 'an upload RPC'

      it 'hands out a presigned POST for the file' do
        result = connect_call(initiate_update, initiate_request(asset_file, content_type: 'image/webp')).upload

        expect(result.file_id).to eq(asset_file.id)
        expect(result.fields.to_h).to include('Content-Type' => 'image/webp')
      end

      it "answers not_found for another sponsorship's file" do
        expect(connect_call(initiate_update, initiate_request(image(other_sponsorship)))).to have_attributes(code: 'not_found')
      end

      it 'answers failed_precondition for the file of a withdrawn event' do
        event = FactoryBot.create(:sponsor_event, sponsorship:, conference:, status: :withdrawn)
        asset_file.update!(sponsor_event: event)

        expect(call).to have_attributes(code: 'failed_precondition')
      end

      it 'refuses a GIF' do
        expect(violations_of(connect_call(initiate_update, initiate_request(asset_file, content_type: 'image/gif')))).to eq([['contentType', 'STRING_IN']])
      end
    end

    describe 'CompleteSponsorEventAssetUpload' do
      let(:asset_file) { image(content_type: 'image/png') }
      let(:call) { connect_call(complete_upload, complete_request(asset_file, extension: 'png')) }

      it_behaves_like 'an upload RPC'

      it 'records what the storage holds' do
        result = connect_call(complete_upload, complete_request(asset_file, version_id: 'v1', extension: 'PNG')).asset_file

        expect(result).to have_attributes(id: asset_file.id, extension: 'png')
        expect(asset_file.reload).to have_attributes(extension: 'png', version_id: 'v2', checksum_sha256: 'sum')
      end

      it 'answers failed_precondition while the storage holds no upload' do
        s3_client.stub_responses(:head_object, 'NotFound')

        expect(call).to have_attributes(code: 'failed_precondition')
      end

      it 'answers invalid_argument for an extension the image cannot have' do
        error = connect_call(complete_upload, complete_request(asset_file, extension: 'gif'))

        expect(error).to have_attributes(code: 'invalid_argument')
      end

      it 'answers failed_precondition for the file of a withdrawn event' do
        event = FactoryBot.create(:sponsor_event, sponsorship:, conference:, status: :withdrawn)
        asset_file.update!(sponsor_event: event)

        expect(call).to have_attributes(code: 'failed_precondition')
      end

      it "answers not_found for another sponsorship's file" do
        expect(connect_call(complete_upload, complete_request(image(other_sponsorship), extension: 'png'))).to have_attributes(code: 'not_found')
      end
    end
  end
end
