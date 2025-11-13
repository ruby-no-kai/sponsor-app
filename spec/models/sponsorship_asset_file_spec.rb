require 'rails_helper'

RSpec.describe SponsorshipAssetFile, type: :model do
  let(:conference) { FactoryBot.create(:conference) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:) }

  describe 'validations' do
    it 'auto-generates handle when not provided' do
      file = FactoryBot.build_stubbed(:sponsorship_asset_file)
      file.handle = nil
      file.valid?
      expect(file.handle).not_to be_nil
    end

    it 'generates handle automatically' do
      file = FactoryBot.create(:sponsorship_asset_file, sponsorship:, extension: 'png')
      expect(file.handle).to be_present
    end
  end

  describe '#object_key' do
    it 'returns S3 object key' do
      file = FactoryBot.create(:sponsorship_asset_file, sponsorship:, extension: 'png', prefix: 'test/')
      expect(file.object_key).to include(file.handle)
      expect(file.object_key).to include(file.id.to_s)
    end

    it 'raises error for unpersisted record' do
      file = FactoryBot.build_stubbed(:sponsorship_asset_file)
      allow(file).to receive(:persisted?).and_return(false)
      expect { file.object_key }.to raise_error(RuntimeError)
    end
  end

  describe '#filename' do
    it 'generates download filename' do
      file = FactoryBot.build_stubbed(:sponsorship_asset_file, sponsorship:, extension: 'png')
      expect(file.filename).to include("S#{file.id}")
      expect(file.filename).to end_with('.png')
    end
  end

  describe '#download_url' do
    it 'generates presigned URL' do
      file = FactoryBot.create(:sponsorship_asset_file, sponsorship:, extension: 'png')

      client_double = instance_double(Aws::S3::Client)
      presigner_double = instance_double(Aws::S3::Presigner)

      allow(Aws::S3::Client).to receive(:new).and_return(client_double)
      allow(Aws::S3::Presigner).to receive(:new).with(client: client_double).and_return(presigner_double)
      allow(presigner_double).to receive(:presigned_url).and_return('https://s3.example.com/signed-url')

      url = file.download_url
      expect(url).to eq('https://s3.example.com/signed-url')
    end
  end

  describe '#copy_to!' do
    it 'copies file to new conference' do
      file = FactoryBot.create(:sponsorship_asset_file, sponsorship:, extension: 'png', prefix: 'old/')
      new_conference = FactoryBot.create(:conference)

      s3_client = instance_double(Aws::S3::Client)
      allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
      allow(s3_client).to receive(:copy_object)

      new_file = file.copy_to!(new_conference)
      expect(new_file).to be_persisted
      expect(new_file.extension).to eq('png')
    end
  end
end
