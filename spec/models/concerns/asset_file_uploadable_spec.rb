# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AssetFileUploadable do
  # Use ExpenseFile as its filename comes from the uploader and may be absent
  describe '#download_url' do
    let(:presigner) { instance_double(Aws::S3::Presigner, presigned_url: 'https://s3.example.com/signed-url') }

    before do
      allow(Aws::S3::Client).to receive(:new).and_return(instance_double(Aws::S3::Client))
      allow(Aws::S3::Presigner).to receive(:new).and_return(presigner)
    end

    it 'signs an empty filename when the file has none' do
      file = FactoryBot.create(:expense_file, filename: nil)

      expect(file.download_url).to eq('https://s3.example.com/signed-url')
      expect(presigner).to have_received(:presigned_url).with(
        :get_object,
        hash_including(response_content_disposition: 'attachment; filename=""'),
      )
    end

    it 'encodes a non-ASCII filename' do
      file = FactoryBot.create(:expense_file, filename: '領収書.pdf')

      file.download_url(disposition: :inline)
      expect(presigner).to have_received(:presigned_url).with(
        :get_object,
        hash_including(response_content_disposition: "inline; filename=\"%E9%A0%98%E5%8F%8E%E6%9B%B8.pdf\"; filename*=UTF-8''%E9%A0%98%E5%8F%8E%E6%9B%B8.pdf"),
      )
    end
  end

  describe '#make_session' do
    before do
      allow(Aws::STS::Client).to receive(:new).and_return(Aws::STS::Client.new(stub_responses: true, region: 'ap-northeast-1'))
    end

    it 'presigns a POST of the object pinned to its content type' do
      file = FactoryBot.create(:expense_file, content_type: 'application/pdf')

      session = file.make_session
      expect(session).to include(id: file.id, max_size: ExpenseFile::MAX_FILE_SIZE, url: start_with('https://dummy.'))
      expect(session.fetch(:fields)).to include('key' => file.object_key, 'Content-Type' => 'application/pdf')
    end

    it 'leaves the content type to the uploader when the file declares none' do
      file = FactoryBot.create(:expense_file, content_type: nil)

      expect(file.make_session.fetch(:fields)).not_to have_key('Content-Type')
    end
  end

  describe '.asset_file_bucket' do
    it 'is available on including models' do
      expect(ExpenseFile.asset_file_bucket).to eq(Rails.application.config.x.asset_file_uploadable.bucket)
    end
  end
end
