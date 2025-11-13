require 'rails_helper'

RSpec.describe Announcement, type: :model do
  let(:conference) { FactoryBot.create(:conference) }
  let(:staff) { FactoryBot.create(:staff) }

  describe 'callbacks' do
    it 'generates issue automatically' do
      announcement = FactoryBot.create(:announcement, staff:, conference:)
      expect(announcement.issue).to be_present
    end

    it 'does not overwrite existing issue' do
      announcement = FactoryBot.create(:announcement, staff:, conference:, issue: 'custom')
      expect(announcement.issue).to eq('custom')
    end
  end

  describe 'scopes' do
    describe '.for_sponsors' do
      let!(:sponsor_announcement) { FactoryBot.create(:announcement, staff:, conference:, exhibitors_only: false) }
      let!(:exhibitor_announcement) { FactoryBot.create(:announcement, :exhibitors_only, staff:, conference:) }

      it 'includes non-exhibitor-only announcements' do
        expect(Announcement.for_sponsors).to include(sponsor_announcement)
      end

      it 'excludes exhibitor-only announcements' do
        expect(Announcement.for_sponsors).not_to include(exhibitor_announcement)
      end
    end
  end

  describe '#to_param' do
    it 'returns issue:locale format' do
      announcement = FactoryBot.build_stubbed(:announcement, staff:, conference:, issue: 'test123', locale: 'en')
      expect(announcement.to_param).to eq('test123:en')
    end
  end

  describe '#published?' do
    it 'returns false when published_at is nil' do
      announcement = FactoryBot.build_stubbed(:announcement, staff:, conference:)
      expect(announcement.published?).to be false
    end

    it 'returns true when published_at is set' do
      announcement = FactoryBot.build_stubbed(:announcement, staff:, conference:, published_at: Time.current)
      expect(announcement.published?).to be true
    end
  end

  describe '#published=' do
    it 'sets published_at when given true' do
      announcement = FactoryBot.build_stubbed(:announcement, staff:, conference:)
      announcement.published = true
      expect(announcement.published_at).to be_present
    end

    it 'clears published_at when given false' do
      announcement = FactoryBot.create(:announcement, staff:, conference:)
      announcement.update!(published_at: Time.current)
      announcement.published = false
      expect(announcement.published_at).to be_nil
    end

    it 'handles string "1" as true' do
      announcement = FactoryBot.build_stubbed(:announcement, staff:, conference:)
      announcement.published = '1'
      expect(announcement.published_at).to be_present
    end
  end

  describe '#pin?' do
    it 'returns true when stickiness > 0' do
      announcement = FactoryBot.build_stubbed(:announcement, :pinned, staff:, conference:)
      expect(announcement.pin?).to be true
    end

    it 'returns false when stickiness is 0' do
      announcement = FactoryBot.build_stubbed(:announcement, staff:, conference:, stickiness: 0)
      expect(announcement.pin?).to be false
    end
  end
end
