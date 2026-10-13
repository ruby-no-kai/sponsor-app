# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AnnouncementIssue do
  let(:conference) { FactoryBot.create(:conference) }

  def announce(issue:, locale: 'en', **attributes)
    FactoryBot.create(:announcement, conference:, issue:, locale:, **attributes)
  end

  describe '.all_of' do
    it 'groups the conference by issue, by pinning priority, then newest first' do
      announce(issue: 'oldest')
      announce(issue: 'pinned', locale: 'ja')
      announce(issue: 'pinned', stickiness: 1)
      announce(issue: 'newest', locale: 'ja')
      announce(issue: 'newest')
      announce(issue: 'stickiest', stickiness: 5)
      FactoryBot.create(:announcement, issue: 'elsewhere')

      issues = described_class.all_of(conference)

      expect(issues.map(&:issue)).to eq(['stickiest', 'pinned', 'newest', 'oldest'])
      expect(issues[1].announcements.map(&:locale)).to eq(['en', 'ja'])
    end

    it 'leaves the bodies unread' do
      announce(issue: 'one')

      announcement = described_class.all_of(conference).sole.announcements.sole

      expect { announcement.body }.to raise_error(ActiveModel::MissingAttributeError)
    end
  end

  describe '.of' do
    it "returns every locale of the announcement's issue in its conference" do
      en = announce(issue: 'shared')
      announce(issue: 'shared', locale: 'ja')
      announce(issue: 'other')
      FactoryBot.create(:announcement, issue: 'shared', locale: 'fr')

      issue = described_class.of(en)

      expect(issue.issue).to eq('shared')
      expect(issue.announcements.map(&:locale)).to eq(['en', 'ja'])
    end
  end

  describe '#latest_revision' do
    it 'is the newest revision among the locales' do
      announce(issue: 'setup', locale: 'ja')
      en = announce(issue: 'setup', revision: 3)

      expect(described_class.of(en).latest_revision).to eq(3)
    end
  end

  it 'refuses an issue without announcements' do
    expect { described_class.new(issue: 'empty', announcements: []) }.to raise_error(ArgumentError)
  end
end
