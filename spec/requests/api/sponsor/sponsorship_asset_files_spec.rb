# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SponsorService logo uploads', type: :request do
  let(:conference) { FactoryBot.create(:conference, :full, application_opens_at: 1.day.ago) }
  let(:head_object) { {version_id: 'v2', last_modified: Time.zone.now, checksum_sha256: 'sum', content_type: 'image/png'} }
  let(:s3_client) { Aws::S3::Client.new(stub_responses: {head_object:}, region: 'ap-northeast-1') }

  let(:create_upload) { connect_method('SponsorService', 'CreateSponsorshipAssetUpload') }
  let(:initiate_update) { connect_method('SponsorService', 'InitiateSponsorshipAssetUpdate') }
  let(:complete_upload) { connect_method('SponsorService', 'CompleteSponsorshipAssetUpload') }

  before do
    allow(Aws::STS::Client).to receive(:new).and_return(Aws::STS::Client.new(stub_responses: true, region: 'ap-northeast-1'))
    allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
  end

  def create_request(slug = conference.slug, **fields)
    Rk::SponsorApp::SponsorServiceCreateSponsorshipAssetUploadRequest.new(conference_slug: slug, content_type: 'image/png', **fields)
  end

  def initiate_request(asset_file, slug = conference.slug, **fields)
    Rk::SponsorApp::SponsorServiceInitiateSponsorshipAssetUpdateRequest.new(conference_slug: slug, asset_file_id: asset_file.id, **fields)
  end

  def complete_request(asset_file, slug = conference.slug, **fields)
    Rk::SponsorApp::SponsorServiceCompleteSponsorshipAssetUploadRequest.new(conference_slug: slug, asset_file_id: asset_file.id, **fields)
  end

  def upload = SponsorshipAssetFile.find(connect_call(create_upload, create_request).upload.file_id)

  def sign_in_as_sponsor
    sponsorship = FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first)
    sign_in_sponsor(sponsorship.contact.email)
    sponsorship
  end

  describe 'CreateSponsorshipAssetUpload' do
    it 'hands out a presigned POST and remembers the file for this browser' do
      result = connect_call(create_upload, create_request).upload

      asset_file = SponsorshipAssetFile.find(result.file_id)
      expect(asset_file).to have_attributes(prefix: "c-#{conference.id}/", content_type: 'image/png', sponsorship: nil)
      expect(result.url).to start_with('https://')
      expect(result.fields.to_h).to include('key' => asset_file.object_key, 'Content-Type' => 'image/png')
      expect(result.max_size).to eq(AssetFileUploadable::MAX_FILE_SIZE)
      expect(session[:asset_file_ids]).to eq([asset_file.id])
    end

    it 'leaves the content type open when the browser cannot tell' do
      result = connect_call(create_upload, create_request.tap { it.clear_content_type }).upload

      expect(result.fields.to_h).not_to have_key('Content-Type')
    end

    it 'answers invalid_argument for a content type no logo has' do
      error = connect_call(create_upload, create_request(content_type: 'text/html'))
      expect(violations_of(error)).to eq([['contentType', 'STRING_IN']])
    end

    it 'answers not_found for an unknown conference' do
      expect(connect_call(create_upload, create_request('unknown'))).to have_attributes(code: 'not_found')
    end

    context 'when the conference is hidden' do
      before { conference.update!(hidden: true) }

      it 'answers not_found without the invitation code' do
        expect(connect_call(create_upload, create_request)).to have_attributes(code: 'not_found', message: "No conference has the slug #{conference.slug.inspect}.")
        expect(SponsorshipAssetFile.count).to eq(0)
      end

      it 'hands out an upload for the invitation code' do
        expect(connect_call(create_upload, create_request(invite_code: conference.invite_code)).upload.file_id).to be_positive
      end
    end

    it 'answers failed_precondition once the sponsorship has a logo' do
      sign_in_as_sponsor
      expect(connect_call(create_upload, create_request)).to have_attributes(code: 'failed_precondition')
    end

    context 'when amendments are closed' do
      before { conference.update!(amendment_closes_at: 1.hour.ago) }

      it 'answers failed_precondition' do
        expect(connect_call(create_upload, create_request)).to have_attributes(code: 'failed_precondition')
      end

      it 'hands out an upload to staff' do
        sign_in_staff(FactoryBot.create(:staff))
        expect(connect_call(create_upload, create_request).upload.file_id).to be_positive
      end
    end
  end

  describe 'InitiateSponsorshipAssetUpdate' do
    it 'hands out a presigned POST for a file of this browser' do
      asset_file = upload

      result = connect_call(initiate_update, initiate_request(asset_file, content_type: 'application/pdf')).upload
      expect(result.file_id).to eq(asset_file.id)
      expect(result.fields.to_h).to include('Content-Type' => 'application/pdf')
      expect(asset_file.reload.content_type).to eq('image/png')
    end

    it "hands out a presigned POST for the sponsorship's logo" do
      sponsorship = sign_in_as_sponsor

      expect(connect_call(initiate_update, initiate_request(sponsorship.asset_file)).upload.file_id).to eq(sponsorship.asset_file.id)
    end

    it 'answers not_found for a file another browser uploaded' do
      asset_file = SponsorshipAssetFile.prepare(conference:).tap(&:save!)
      expect(connect_call(initiate_update, initiate_request(asset_file))).to have_attributes(code: 'not_found')
    end

    it "answers not_found for another sponsorship's logo" do
      sign_in_as_sponsor
      other = FactoryBot.create(:sponsorship, conference:, plan: nil)

      expect(connect_call(initiate_update, initiate_request(other.asset_file))).to have_attributes(code: 'not_found')
    end

    it 'answers as for an unknown slug when the file was uploaded for another conference' do
      hidden = FactoryBot.create(:conference, :full, application_opens_at: 1.day.ago, hidden: true)

      error = connect_call(initiate_update, initiate_request(upload, hidden.slug))
      expect(error).to have_attributes(code: 'not_found', message: "No conference has the slug #{hidden.slug.inspect}.")
    end

    it 'answers failed_precondition once amendments close' do
      asset_file = upload
      conference.update!(amendment_closes_at: 1.hour.ago)

      expect(connect_call(initiate_update, initiate_request(asset_file))).to have_attributes(code: 'failed_precondition')
    end
  end

  describe 'CompleteSponsorshipAssetUpload' do
    it 'records what the storage holds' do
      asset_file = upload

      result = connect_call(complete_upload, complete_request(asset_file, version_id: 'v2', extension: 'P.N-G'))

      expect(result.asset_file).to have_attributes(id: asset_file.id, extension: 'png')
      expect(asset_file.reload).to have_attributes(extension: 'png', version_id: 'v2', checksum_sha256: 'sum', content_type: 'image/png')
    end

    it 'records an extension it cannot read as unknown' do
      asset_file = upload
      expect(connect_call(complete_upload, complete_request(asset_file, extension: '..')).asset_file.extension).to eq('unknown')
    end

    context 'when the storage holds no upload' do
      let(:head_object) { 'NotFound' }

      it 'answers failed_precondition' do
        error = connect_call(complete_upload, complete_request(upload))
        expect(error).to have_attributes(code: 'failed_precondition')
        expect(problem_type_of(error)).to eq('failed-precondition')
      end
    end

    context 'when the storage holds a file of a type no logo has' do
      let(:head_object) { {version_id: 'v2', last_modified: Time.zone.now, content_type: 'text/html'} }

      it 'answers invalid_argument' do
        asset_file = upload

        error = connect_call(complete_upload, complete_request(asset_file))
        expect(error).to have_attributes(code: 'invalid_argument')
        expect(problem_type_of(error)).to eq('invalid-record')
        expect(asset_file.reload.content_type).to eq('image/png')
      end
    end

    it 'answers not_found for a file another browser uploaded' do
      asset_file = SponsorshipAssetFile.prepare(conference:).tap(&:save!)
      expect(connect_call(complete_upload, complete_request(asset_file))).to have_attributes(code: 'not_found')
    end

    it 'answers as for an unknown slug when the file was uploaded for another conference' do
      hidden = FactoryBot.create(:conference, :full, application_opens_at: 1.day.ago, hidden: true)
      asset_file = upload

      error = connect_call(complete_upload, complete_request(asset_file, hidden.slug, version_id: 'v2'))
      expect(error).to have_attributes(code: 'not_found', message: "No conference has the slug #{hidden.slug.inspect}.")
      expect(asset_file.reload.version_id).not_to eq('v2')
    end

    it 'answers not_found for a file of this browser under a conference that does not exist' do
      expect(connect_call(complete_upload, complete_request(upload, 'unknown'))).to have_attributes(code: 'not_found')
    end
  end

  it 'takes the content types SponsorshipAssetFile allows, and no other' do
    rules = Google::Protobuf::DescriptorPool.generated_pool.lookup('buf.validate.field')
    [
      Rk::SponsorApp::SponsorServiceCreateSponsorshipAssetUploadRequest,
      Rk::SponsorApp::SponsorServiceInitiateSponsorshipAssetUpdateRequest,
    ].each do |request_class|
      field = request_class.descriptor.lookup('content_type')

      expect(rules.get(field.options).string.in.to_a).to eq(SponsorshipAssetFile::ALLOWED_CONTENT_TYPES), request_class.name
    end
  end
end
