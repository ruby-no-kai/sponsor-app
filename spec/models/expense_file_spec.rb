# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExpenseFile, type: :model do
  let(:conference) { FactoryBot.create(:conference) }
  let(:plan) { FactoryBot.create(:plan, conference:) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:, customization: true) }

  describe '.prepare' do
    it 'sets the correct prefix' do
      file = described_class.prepare(conference:, sponsorship:)
      expect(file.prefix).to eq("c-#{conference.id}/expenses/s-#{sponsorship.id}/")
      expect(file.sponsorship).to eq(sponsorship)
    end
  end

  describe '#filename' do
    it 'returns the stored filename attribute' do
      file = FactoryBot.build(:expense_file, sponsorship:, filename: 'receipt.pdf')
      expect(file.filename).to eq('receipt.pdf')
    end
  end

  describe 'content_type validation' do
    %w[image/jpeg image/png image/gif image/webp application/pdf].each do |type|
      it "allows #{type}" do
        file = described_class.prepare(conference:, sponsorship:)
        file.content_type = type
        file.valid?
        expect(file.errors[:content_type]).to be_empty
      end
    end

    %w[text/plain application/zip image/svg+xml application/javascript].each do |type|
      it "rejects #{type}" do
        file = described_class.prepare(conference:, sponsorship:)
        file.content_type = type
        file.valid?
        expect(file.errors[:content_type]).to be_present
      end
    end
  end

  describe 'AssetFileUploadable' do
    it 'generates a handle on validation' do
      file = described_class.prepare(conference:, sponsorship:)
      file.valid?
      expect(file.handle).to be_present
    end
  end

  describe 'S3 cleanup on destroy' do
    it 'calls delete_object on S3 after destroy' do
      file = described_class.prepare(conference:, sponsorship:)
      file.save!

      s3_client = instance_double(Aws::S3::Client)
      allow(file).to receive(:s3_client).and_return(s3_client)
      allow(s3_client).to receive(:delete_object)

      object_key = file.object_key
      file.destroy!

      expect(s3_client).to have_received(:delete_object).with(
        bucket: described_class.asset_file_bucket,
        key: object_key,
      )
    end
  end

  describe 'cascade delete of join records' do
    it 'destroys expense_line_item_files when file is destroyed' do
      file = described_class.prepare(conference:, sponsorship:)
      file.save!

      report = FactoryBot.create(:expense_report, sponsorship:)
      item = FactoryBot.create(:expense_line_item, expense_report: report, position: 1)
      ExpenseLineItemFile.create!(expense_line_item: item, expense_file: file)

      s3_client = instance_double(Aws::S3::Client)
      allow(file).to receive(:s3_client).and_return(s3_client)
      allow(s3_client).to receive(:delete_object)

      expect { file.destroy! }.to change(ExpenseLineItemFile, :count).by(-1)
    end
  end
end
