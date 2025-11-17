require 'rails_helper'

RSpec.describe EditingHistory do
  # Use SponsorshipEditingHistory as it includes the concern
  let(:conference) { FactoryBot.create(:conference) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:) }
  let(:staff) { FactoryBot.create(:staff) }

  describe '#calculate_diff' do
    context 'when there is no previous history' do
      it 'calculates diff from empty state' do
        # Create a sponsorship and clear its auto-created history
        sp = FactoryBot.create(:sponsorship, conference:)
        sp.editing_histories.delete_all

        history = SponsorshipEditingHistory.create!(sponsorship: sp, raw: {'name' => 'Test'})
        expect(history.diff).to be_an(Array)
        expect(history.diff).not_to be_empty
      end
    end

    context 'when there is previous history' do
      let!(:first_history) do
        SponsorshipEditingHistory.create!(
          sponsorship:,
          raw: {name: 'First', url: 'http://example.com'}
        )
      end

      it 'calculates diff from last history' do
        second_history = SponsorshipEditingHistory.create!(
          sponsorship:,
          raw: {name: 'Second', url: 'http://example.com'}
        )

        expect(second_history.diff).not_to be_nil
        expect(second_history.diff).to be_an(Array)
      end

      it 'uses Hashdiff to calculate differences' do
        second_history = SponsorshipEditingHistory.new(
          sponsorship:,
          raw: {name: 'Second', url: 'http://example.com', new_field: 'value'}
        )

        second_history.save!

        # Hashdiff returns array of changes like [["~", "name", "First", "Second"], ["+", "new_field", "value"]]
        expect(second_history.diff).to be_an(Array)
        expect(second_history.diff.any? { |change| change[1] == 'name' }).to be true
      end

      it 'does not recalculate diff if already set' do
        second_history = SponsorshipEditingHistory.new(
          sponsorship:,
          raw: {name: 'Second', url: 'http://example.com'}
        )
        second_history.diff = [['existing', 'diff']]
        second_history.save!

        expect(second_history.diff).to eq([['existing', 'diff']])
      end
    end
  end

  describe '#diff_summary' do
    it 'returns formatted summary of changes' do
      history = SponsorshipEditingHistory.new(sponsorship:, raw: {})
      history.diff = [
        ['~', 'name', 'Old Name', 'New Name'],
        ['+', 'new_field', 'value']
      ]

      summary = history.diff_summary
      expect(summary).to include('~name')
      expect(summary).to include('+new_field')
      expect(summary.size).to eq(2)
    end

    it 'handles empty diff' do
      history = SponsorshipEditingHistory.new(sponsorship:, raw: {name: 'Test'})
      history.diff = []
      expect(history.diff_summary).to eq([])
    end
  end

  describe '#last_raw (private method)' do
    context 'for a new record' do
      it 'returns last history raw data' do
        # Clear auto-created history first
        sponsorship.editing_histories.delete_all

        first_history = SponsorshipEditingHistory.create!(
          sponsorship:,
          raw: {'name' => 'First'}
        )

        second_history = SponsorshipEditingHistory.new(
          sponsorship:,
          raw: {'name' => 'Second'}
        )

        # Access private method for testing
        last_raw = second_history.send(:last_raw)
        expect(last_raw).to eq({'name' => 'First'})
      end

      it 'returns existing history when sponsorship has history' do
        # Sponsorship already has history from factory
        history = SponsorshipEditingHistory.new(sponsorship:, raw: {'name' => 'New'})
        last_raw = history.send(:last_raw)
        expect(last_raw).to be_a(Hash)
        expect(last_raw).not_to be_empty
      end
    end

    context 'for a persisted record' do
      it 'returns previous history raw data' do
        first_history = SponsorshipEditingHistory.create!(
          sponsorship:,
          raw: {'name' => 'First'}
        )
        second_history = SponsorshipEditingHistory.create!(
          sponsorship:,
          raw: {'name' => 'Second'}
        )
        third_history = SponsorshipEditingHistory.create!(
          sponsorship:,
          raw: {'name' => 'Third'}
        )

        # For second_history, last_raw should be first_history
        last_raw = second_history.send(:last_raw)
        expect(last_raw).to eq({'name' => 'First'})
      end

      it 'returns empty hash when no previous history' do
        # Clear auto-created history first
        sponsorship.editing_histories.delete_all

        # Create first history
        history = SponsorshipEditingHistory.create!(sponsorship:, raw: {'name' => 'First'})

        # Clear memoization
        history.instance_variable_set(:@last_raw, nil)

        last_raw = history.send(:last_raw)
        expect(last_raw).to eq({})
      end
    end
  end
end
