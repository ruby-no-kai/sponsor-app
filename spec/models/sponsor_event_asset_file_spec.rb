# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SponsorEventAssetFile, type: :model do
  let(:conference) { FactoryBot.create(:conference) }
  let(:plan) { FactoryBot.create(:plan, conference:) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:) }

  describe 'content_type validation' do
    %w[image/jpeg image/png image/gif image/webp].each do |type|
      it "allows #{type}" do
        file = FactoryBot.build(:sponsor_event_asset_file, sponsorship:, content_type: type)
        file.valid?
        expect(file.errors[:content_type]).to be_empty
      end
    end

    %w[application/pdf image/svg+xml text/html application/zip].each do |type|
      it "rejects #{type}" do
        file = FactoryBot.build(:sponsor_event_asset_file, sponsorship:, content_type: type)
        file.valid?
        expect(file.errors[:content_type]).to be_present
      end
    end

    it 'allows blank content_type' do
      file = FactoryBot.build(:sponsor_event_asset_file, sponsorship:, content_type: nil)
      file.valid?
      expect(file.errors[:content_type]).to be_empty
    end
  end
end
