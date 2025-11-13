require 'rails_helper'

RSpec.describe Plan, type: :model do

  describe '#booth_eligible?' do
    it 'returns true when booth_size is greater than 0' do
      plan = FactoryBot.build_stubbed(:plan, booth_size: 6)
      expect(plan.booth_eligible?).to be true
    end

    it 'returns false when booth_size is 0' do
      plan = FactoryBot.build_stubbed(:plan, booth_size: 0)
      expect(plan.booth_eligible?).to be false
    end

    it 'returns false when booth_size is nil' do
      plan = FactoryBot.build_stubbed(:plan, booth_size: nil)
      expect(plan.booth_eligible?).to be false
    end

    it 'returns true for positive booth_size values' do
      plan = FactoryBot.build_stubbed(:plan, booth_size: 1)
      expect(plan.booth_eligible?).to be true
    end
  end

  describe '#sold_out?' do
    let!(:plan) { FactoryBot.create(:plan, capacity: 3) }

    it 'returns false when active sponsorships are below capacity' do
      2.times do
        sponsorship = FactoryBot.create(:sponsorship, plan:, conference: plan.conference)
        sponsorship.update!(accepted_at: Time.current)
      end

      expect(plan.sold_out?).to be false
    end

    it 'returns true when active sponsorships reach capacity' do
      3.times do
        sponsorship = FactoryBot.create(:sponsorship, plan:, conference: plan.conference)
        sponsorship.update!(accepted_at: Time.current)
      end

      expect(plan.sold_out?).to be true
    end

    it 'only counts active sponsorships' do
      2.times do
        sponsorship = FactoryBot.create(:sponsorship, plan:, conference: plan.conference)
        sponsorship.update!(accepted_at: Time.current)
      end
      # One pending
      FactoryBot.create(:sponsorship, plan:, conference: plan.conference)

      expect(plan.sold_out?).to be false
    end

    it 'does not count withdrawn sponsorships' do
      3.times do |i|
        sponsorship = FactoryBot.create(:sponsorship, plan:, conference: plan.conference)
        sponsorship.update!(accepted_at: Time.current)
        # Withdraw one
        sponsorship.update!(withdrawn_at: Time.current) if i == 2
      end

      expect(plan.sold_out?).to be false
    end
  end

  describe '#closed?' do
    it 'returns false when closes_at is nil' do
      plan = FactoryBot.build_stubbed(:plan, closes_at: nil)
      expect(plan.closed?).to be false
    end

    it 'returns true when closes_at is in the past' do
      plan = FactoryBot.build_stubbed(:plan, closes_at: 1.day.ago)
      expect(plan.closed?).to be true
    end

    it 'returns false when closes_at is in the future' do
      plan = FactoryBot.build_stubbed(:plan, closes_at: 1.day.from_now)
      expect(plan.closed?).to be false
    end

    it 'accepts time parameter' do
      plan = FactoryBot.build_stubbed(:plan, closes_at: Time.zone.parse('2025-06-01'))
      expect(plan.closed?(Time.zone.parse('2025-05-31'))).to be false
      expect(plan.closed?(Time.zone.parse('2025-06-01'))).to be true
      expect(plan.closed?(Time.zone.parse('2025-06-02'))).to be true
    end

    it 'defaults to current time' do
      plan = FactoryBot.build_stubbed(:plan, closes_at: 1.hour.from_now)
      expect(plan.closed?).to be false
      expect(plan.closed?(Time.zone.now)).to be false
    end
  end

  describe '#available?' do
    let!(:plan) { FactoryBot.create(:plan, capacity: 2) }

    it 'returns true when not sold out and not closed' do
      expect(plan.available?).to be true
    end

    it 'returns false when sold out' do
      2.times do
        sponsorship = FactoryBot.create(:sponsorship, plan:, conference: plan.conference)
        sponsorship.update!(accepted_at: Time.current)
      end

      expect(plan.available?).to be false
    end

    it 'returns false when closed' do
      plan.update!(closes_at: 1.day.ago)
      expect(plan.available?).to be false
    end

    it 'returns false when both sold out and closed' do
      plan.update!(closes_at: 1.day.ago)

      2.times do
        sponsorship = FactoryBot.create(:sponsorship, plan:, conference: plan.conference)
        sponsorship.update!(accepted_at: Time.current)
      end

      expect(plan.available?).to be false
    end

    it 'accepts time parameter' do
      plan.update!(closes_at: 1.day.from_now)
      expect(plan.available?(2.days.from_now)).to be false
      expect(plan.available?(Time.zone.now)).to be true
    end
  end

  describe '#words_limit_hard' do
    it 'returns 110% of words_limit' do
      plan = FactoryBot.build_stubbed(:plan, words_limit: 100)
      expect(plan.words_limit_hard).to be_within(0.01).of(110.0)
    end

    it 'returns 0 when words_limit is nil' do
      plan = FactoryBot.build_stubbed(:plan, words_limit: nil)
      expect(plan.words_limit_hard).to eq(0.0)
    end

    it 'calculates correctly for different word limits' do
      plan = FactoryBot.build_stubbed(:plan, words_limit: 250)
      expect(plan.words_limit_hard).to eq(275.0)
    end

    it 'handles zero words_limit' do
      plan = FactoryBot.build_stubbed(:plan, words_limit: 0)
      expect(plan.words_limit_hard).to eq(0.0)
    end
  end
end
