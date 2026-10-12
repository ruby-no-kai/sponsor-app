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
end
