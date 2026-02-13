require 'rails_helper'

RSpec.describe SponsorEvent, type: :model do
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:) }

  describe 'associations' do
    it 'belongs to sponsorship' do
      expect(SponsorEvent.reflect_on_association(:sponsorship).macro).to eq(:belongs_to)
    end

    it 'belongs to conference' do
      expect(SponsorEvent.reflect_on_association(:conference).macro).to eq(:belongs_to)
    end
  end

  describe 'validations' do
    describe 'title' do
      it 'requires title' do
        event = FactoryBot.build(:sponsor_event, sponsorship:, title: nil)
        expect(event).not_to be_valid
        expect(event.errors[:title]).to be_present
      end
    end

    describe 'starts_at' do
      it 'requires starts_at' do
        event = FactoryBot.build(:sponsor_event, sponsorship:, starts_at: nil)
        expect(event).not_to be_valid
        expect(event.errors[:starts_at]).to be_present
      end
    end

    describe 'url' do
      it 'requires url' do
        event = FactoryBot.build(:sponsor_event, sponsorship:, url: nil)
        expect(event).not_to be_valid
        expect(event.errors[:url]).to be_present
      end

      it 'accepts http urls' do
        event = FactoryBot.build(:sponsor_event, sponsorship:, url: 'http://example.com')
        expect(event).to be_valid
      end

      it 'accepts https urls' do
        event = FactoryBot.build(:sponsor_event, sponsorship:, url: 'https://example.com')
        expect(event).to be_valid
      end

      it 'rejects non-http urls' do
        event = FactoryBot.build(:sponsor_event, sponsorship:, url: 'ftp://example.com')
        expect(event).not_to be_valid
        expect(event.errors[:url]).to include('must be a valid HTTP(S) URL')
      end
    end

    describe 'policy_acknowledged_at on create' do
      it 'requires policy_acknowledged_at on create' do
        event = FactoryBot.build(:sponsor_event, sponsorship:, policy_acknowledged_at: nil)
        expect(event).not_to be_valid
        expect(event.errors[:policy_acknowledged_at]).to include('must be acknowledged')
      end
    end

    describe 'co_host_sponsorship_ids validation' do
      let(:other_sponsorship) { FactoryBot.create(:sponsorship, conference:) }
      let(:different_conference) { FactoryBot.create(:conference, :full) }
      let(:different_conference_plan) { FactoryBot.create(:plan, conference: different_conference) }
      let(:different_conference_sponsorship) { FactoryBot.create(:sponsorship, conference: different_conference, plan: different_conference_plan) }

      it 'allows sponsorship ids from the same conference' do
        event = FactoryBot.build(:sponsor_event, sponsorship:, co_host_sponsorship_ids: [other_sponsorship.id])
        expect(event).to be_valid
      end

      it 'rejects sponsorship ids from different conferences' do
        event = FactoryBot.build(:sponsor_event, sponsorship:, co_host_sponsorship_ids: [different_conference_sponsorship.id])
        expect(event).not_to be_valid
        expect(event.errors[:co_host_sponsorship_ids]).to be_present
      end
    end
  end

  describe 'slug generation' do
    it 'generates slug on create' do
      event = FactoryBot.create(:sponsor_event, sponsorship:)
      expect(event.slug).to eq("#{sponsorship.organization.domain}-1")
    end

    it 'increments sequence for multiple events' do
      FactoryBot.create(:sponsor_event, sponsorship:)
      event2 = FactoryBot.create(:sponsor_event, sponsorship:)
      expect(event2.slug).to eq("#{sponsorship.organization.domain}-2")
    end

    it 'does not overwrite existing slug' do
      event = FactoryBot.build(:sponsor_event, sponsorship:, slug: 'custom-slug')
      event.save!
      expect(event.slug).to eq('custom-slug')
    end
  end

  describe '#editable_by_sponsor?' do
    it 'returns true for pending events' do
      event = FactoryBot.build(:sponsor_event, :pending, sponsorship:)
      expect(event.editable_by_sponsor?).to be true
    end

    it 'returns true for accepted events' do
      event = FactoryBot.build(:sponsor_event, :accepted, sponsorship:)
      expect(event.editable_by_sponsor?).to be true
    end

    it 'returns true for rejected events' do
      event = FactoryBot.build(:sponsor_event, :rejected, sponsorship:)
      expect(event.editable_by_sponsor?).to be true
    end

    it 'returns false for withdrawn events' do
      event = FactoryBot.build(:sponsor_event, :withdrawn, sponsorship:)
      expect(event.editable_by_sponsor?).to be false
    end
  end

  describe '#to_h_for_history' do
    it 'returns all tracked fields' do
      event = FactoryBot.create(:sponsor_event, :with_details, sponsorship:)
      history = event.to_h_for_history

      expect(history).to include(
        'sponsorship_id' => event.sponsorship_id,
        'conference_id' => event.conference_id,
        'slug' => event.slug,
        'title' => event.title,
        'url' => event.url,
        'status' => 'pending'
      )
    end
  end

  describe '#all_host_sponsorships' do
    let(:co_host) { FactoryBot.create(:sponsorship, conference:) }

    it 'includes primary sponsorship' do
      event = FactoryBot.create(:sponsor_event, sponsorship:)
      expect(event.all_host_sponsorships).to include(sponsorship)
    end

    it 'includes non-withdrawn co-hosts' do
      event = FactoryBot.create(:sponsor_event, sponsorship:, co_host_sponsorship_ids: [co_host.id])
      expect(event.all_host_sponsorships).to include(co_host)
    end

    it 'excludes withdrawn co-hosts' do
      co_host.update!(withdrawn_at: Time.current)
      event = FactoryBot.create(:sponsor_event, sponsorship:, co_host_sponsorship_ids: [co_host.id])
      expect(event.all_host_sponsorships).not_to include(co_host)
    end
  end

  describe 'editing history' do
    it 'creates history record on save' do
      event = FactoryBot.build(:sponsor_event, sponsorship:)
      expect { event.save! }.to change(SponsorEventEditingHistory, :count).by(1)
    end

    it 'stores staff attribution' do
      staff = FactoryBot.create(:staff)
      event = FactoryBot.build(:sponsor_event, sponsorship:)
      event.staff = staff
      event.save!

      expect(event.last_editing_history.staff).to eq(staff)
    end
  end
end
