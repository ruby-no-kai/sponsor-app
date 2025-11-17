require 'rails_helper'

RSpec.describe EditingHistoryTarget do
  # Use Sponsorship as it includes the concern
  let(:conference) { FactoryBot.create(:conference) }
  let(:staff) { FactoryBot.create(:staff) }
  let(:organization) { FactoryBot.create(:organization) }

  describe 'associations' do
    it 'has many editing_histories ordered by id desc' do
      sponsorship = FactoryBot.create(:sponsorship,
        conference:,
        name: 'Test'
      )

      # Histories are created automatically via around_save
      expect(sponsorship.editing_histories).to be_present
      expect(sponsorship.editing_histories.first).to be_a(SponsorshipEditingHistory)
    end

    it 'destroys editing_histories when target is destroyed' do
      sponsorship = FactoryBot.create(:sponsorship,
        conference:,
        name: "Test"
      )

      history_ids = sponsorship.editing_histories.pluck(:id)
      expect(history_ids).not_to be_empty

      sponsorship.destroy

      history_ids.each do |id|
        expect(SponsorshipEditingHistory.find_by(id:)).to be_nil
      end
    end
  end

  describe '#staff accessor' do
    it 'provides staff attribute accessor' do
      sponsorship = Sponsorship.new(
        conference:,
        name: "Test"
      )

      expect(sponsorship).to respond_to(:staff)
      expect(sponsorship).to respond_to(:staff=)

      sponsorship.staff = staff
      expect(sponsorship.staff).to eq(staff)
    end
  end

  describe '#create_history' do
    it 'creates editing history on save' do
      sponsorship = FactoryBot.build(:sponsorship,
        conference:,
        name: "Test"
      )

      expect {
        sponsorship.save!
      }.to change { SponsorshipEditingHistory.count }.by(1)

      history = sponsorship.editing_histories.first
      expect(history.raw).to be_present
      expect(history.raw).to be_a(Hash)
    end

    it 'associates staff with history when staff is set' do
      sponsorship = FactoryBot.build(:sponsorship,
        conference:,
        name: "Test"
      )
      sponsorship.staff = staff

      sponsorship.save!

      history = sponsorship.editing_histories.first
      expect(history.staff).to eq(staff)
    end

    it 'creates history without staff when staff is not set' do
      sponsorship = FactoryBot.build(:sponsorship,
        conference:,
        name: "Test"
      )

      sponsorship.save!

      history = sponsorship.editing_histories.first
      expect(history.staff).to be_nil
    end

    it 'calls to_h_for_history to capture snapshot' do
      sponsorship = FactoryBot.build(:sponsorship,
        conference:,
        name: 'Test Sponsor',
      )

      sponsorship.save!

      history = sponsorship.editing_histories.first
      expect(history.raw['name']).to eq('Test Sponsor')
      expect(history.raw['url']).to be_present
      expect(history.raw['profile']).to be_present
    end

    it 'creates history on update' do
      sponsorship = FactoryBot.create(:sponsorship,
        conference:,
        name: 'Initial Name',
      )

      initial_history_count = sponsorship.editing_histories.count

      sponsorship.update!(name: 'Updated Name')

      expect(sponsorship.editing_histories.count).to eq(initial_history_count + 1)

      latest_history = sponsorship.editing_histories.first
      expect(latest_history.raw['name']).to eq('Updated Name')
    end

    it 'tracks changes between saves' do
      sponsorship = FactoryBot.create(:sponsorship,
        conference:,
        name: 'First Name',
        profile: 'First profile',
      )

      sponsorship.update!(name: 'Second Name', profile: 'Second profile')

      histories = sponsorship.editing_histories.order(id: :desc)
      expect(histories.count).to eq(2)

      latest = histories.first
      previous = histories.second

      expect(latest.raw['name']).to eq('Second Name')
      expect(previous.raw['name']).to eq('First Name')
    end
  end

  describe '#last_editing_history' do
    it 'returns the most recent editing history by id asc' do
      sponsorship = FactoryBot.create(:sponsorship,
        conference:,
        name: "Test"
      )

      sponsorship.update!(name: 'Updated')
      sponsorship.update!(name: 'Updated Again')

      # last_editing_history orders by id: :asc and takes last, which gives the highest ID
      last_history = sponsorship.last_editing_history
      all_histories = sponsorship.editing_histories.reorder(id: :asc)

      expect(last_history).to eq(all_histories.last)
      expect(last_history.raw['name']).to eq('Updated Again')
    end

    it 'memoizes the result' do
      sponsorship = FactoryBot.create(:sponsorship,
        conference:,
        name: "Test"
      )

      first_call = sponsorship.last_editing_history
      second_call = sponsorship.last_editing_history

      expect(first_call.object_id).to eq(second_call.object_id)
    end
  end
end
