require 'rails_helper'

RSpec.describe Sponsorship, type: :model do
  let(:conference) { FactoryBot.create(:conference) }
  let(:plan) { FactoryBot.create(:plan, conference:, number_of_guests: 3) }

  describe 'scopes' do
    let!(:active_sponsorship) do
      sponsorship = FactoryBot.create(:sponsorship, conference:, plan:)
      sponsorship.update!(accepted_at: Time.current)
      sponsorship
    end

    let!(:pending_sponsorship) do
      FactoryBot.create(:sponsorship, conference:)
    end

    let!(:withdrawn_sponsorship) do
      sponsorship = FactoryBot.create(:sponsorship, conference:, plan:)
      sponsorship.update!(accepted_at: Time.current, withdrawn_at: Time.current)
      sponsorship
    end

    describe '.active' do
      it 'includes accepted and not withdrawn sponsorships' do
        expect(Sponsorship.active).to include(active_sponsorship)
      end

      it 'excludes pending sponsorships' do
        expect(Sponsorship.active).not_to include(pending_sponsorship)
      end

      it 'excludes withdrawn sponsorships' do
        expect(Sponsorship.active).not_to include(withdrawn_sponsorship)
      end
    end

    describe '.pending' do
      it 'includes not accepted and not withdrawn sponsorships' do
        expect(Sponsorship.pending).to include(pending_sponsorship)
      end

      it 'excludes accepted sponsorships' do
        expect(Sponsorship.pending).not_to include(active_sponsorship)
      end

      it 'excludes withdrawn sponsorships' do
        expect(Sponsorship.pending).not_to include(withdrawn_sponsorship)
      end
    end

    describe '.accepted' do
      it 'includes sponsorships with accepted_at set' do
        expect(Sponsorship.accepted).to include(active_sponsorship)
      end

      it 'excludes sponsorships without accepted_at' do
        expect(Sponsorship.accepted).not_to include(pending_sponsorship)
      end
    end

    describe '.not_accepted' do
      it 'includes sponsorships without accepted_at' do
        expect(Sponsorship.not_accepted).to include(pending_sponsorship)
      end

      it 'excludes accepted sponsorships' do
        expect(Sponsorship.not_accepted).not_to include(active_sponsorship)
      end
    end

    describe '.withdrawn' do
      it 'includes sponsorships with withdrawn_at set' do
        expect(Sponsorship.withdrawn).to include(withdrawn_sponsorship)
      end

      it 'excludes sponsorships without withdrawn_at' do
        expect(Sponsorship.withdrawn).not_to include(active_sponsorship)
      end
    end

    describe '.not_withdrawn' do
      it 'includes sponsorships without withdrawn_at' do
        expect(Sponsorship.not_withdrawn).to include(active_sponsorship)
        expect(Sponsorship.not_withdrawn).to include(pending_sponsorship)
      end

      it 'excludes withdrawn sponsorships' do
        expect(Sponsorship.not_withdrawn).not_to include(withdrawn_sponsorship)
      end
    end

    describe '.plan_determined' do
      let!(:no_plan_sponsorship) do
        FactoryBot.create(:sponsorship, conference:, plan: nil)
      end

      it 'includes sponsorships with plan' do
        expect(Sponsorship.plan_determined).to include(active_sponsorship)
      end

      it 'excludes sponsorships without plan' do
        expect(Sponsorship.plan_determined).not_to include(no_plan_sponsorship)
      end
    end

    describe '.have_presence' do
      let!(:suspended_sponsorship) do
        sponsorship = FactoryBot.create(:sponsorship, conference:, plan:, suspended: true)
        sponsorship.update!(accepted_at: Time.current)
        sponsorship
      end

      it 'includes active, plan-determined, non-suspended sponsorships' do
        expect(Sponsorship.have_presence).to include(active_sponsorship)
      end

      it 'excludes suspended sponsorships' do
        expect(Sponsorship.have_presence).not_to include(suspended_sponsorship)
      end

      it 'excludes pending sponsorships' do
        pending_sponsorship.update!(plan:)
        expect(Sponsorship.have_presence).not_to include(pending_sponsorship)
      end

      it 'excludes sponsorships without plan' do
        expect(Sponsorship.have_presence).not_to include(pending_sponsorship)
      end
    end
  end

  describe 'validations' do
    it 'requires unique organization per conference' do
      organization = FactoryBot.create(:organization)
      FactoryBot.create(:sponsorship, conference:)
      # Manually set the organization after creation to match the existing one
      existing_sponsorship = conference.sponsorships.first
      existing_sponsorship.update_column(:organization_id, organization.id)

      duplicate = Sponsorship.new(
        conference:,
        organization:,
        name: 'Test',
        url: 'https://example.com',
        profile: 'Test profile',
        locale: 'en'
      )
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:organization]).to be_present
    end

    it 'allows same organization for different conferences' do
      organization = FactoryBot.create(:organization)
      FactoryBot.create(:sponsorship, conference:, organization:)
      other_conference = FactoryBot.create(:conference)
      other_sponsorship = FactoryBot.build(:sponsorship, conference: other_conference, organization:)
      expect(other_sponsorship).to be_valid
    end




  end

  describe 'state management' do
    describe '#accepted?' do
      it 'returns false when accepted_at is nil' do
        sponsorship = FactoryBot.build_stubbed(:sponsorship, conference:)
        expect(sponsorship.accepted?).to be false
      end

      it 'returns true when accepted_at is set' do
        sponsorship = FactoryBot.create(:sponsorship, conference:)
        sponsorship.update!(accepted_at: Time.current)
        expect(sponsorship.accepted?).to be true
      end
    end

    describe '#accepted=' do
      it 'sets accepted_at when given true' do
        sponsorship = FactoryBot.build_stubbed(:sponsorship, conference:)
        sponsorship.accepted = true
        expect(sponsorship.accepted_at).to be_present
      end

      it 'clears accepted_at when given false' do
        sponsorship = FactoryBot.create(:sponsorship, conference:)
        sponsorship.update!(accepted_at: Time.current)
        sponsorship.accepted = false
        expect(sponsorship.accepted_at).to be_nil
      end

      it 'handles string "1" as true' do
        sponsorship = FactoryBot.build_stubbed(:sponsorship, conference:)
        sponsorship.accepted = '1'
        expect(sponsorship.accepted_at).to be_present
      end

      it 'handles string "0" as false' do
        sponsorship = FactoryBot.create(:sponsorship, conference:)
        sponsorship.update!(accepted_at: Time.current)
        sponsorship.accepted = '0'
        expect(sponsorship.accepted_at).to be_nil
      end
    end

    describe '#withdrawn?' do
      it 'returns false when withdrawn_at is nil' do
        sponsorship = FactoryBot.build_stubbed(:sponsorship, conference:)
        expect(sponsorship.withdrawn?).to be false
      end

      it 'returns true when withdrawn_at is set' do
        sponsorship = FactoryBot.create(:sponsorship, conference:)
        sponsorship.update!(withdrawn_at: Time.current)
        expect(sponsorship.withdrawn?).to be true
      end
    end

    describe '#withdraw' do
      it 'sets withdrawn_at' do
        sponsorship = FactoryBot.build_stubbed(:sponsorship, conference:)
        sponsorship.withdraw
        expect(sponsorship.withdrawn_at).to be_present
      end

      it 'updates withdrawn_at when called again' do
        sponsorship = FactoryBot.create(:sponsorship, conference:)
        first_time = 2.days.ago
        sponsorship.update!(withdrawn_at: first_time)

        sponsorship.withdraw
        expect(sponsorship.withdrawn_at).to be > first_time
      end
    end

    describe '#active?' do
      it 'returns true when accepted and not withdrawn' do
        sponsorship = FactoryBot.create(:sponsorship, conference:)
        sponsorship.update!(accepted_at: Time.current)
        expect(sponsorship.active?).to be true
      end

      it 'returns false when not accepted' do
        sponsorship = FactoryBot.build_stubbed(:sponsorship, conference:)
        expect(sponsorship.active?).to be false
      end

      it 'returns false when withdrawn' do
        sponsorship = FactoryBot.create(:sponsorship, conference:)
        sponsorship.update!(accepted_at: Time.current, withdrawn_at: Time.current)
        expect(sponsorship.active?).to be false
      end
    end
  end

  describe 'callbacks' do
    describe '#generate_ticket_key' do
      it 'generates ticket_key when not provided' do
        sponsorship = FactoryBot.create(:sponsorship, conference:)
        expect(sponsorship.ticket_key).to be_present
        expect(sponsorship.ticket_key.length).to be > 10
      end

      it 'does not overwrite existing ticket_key' do
        sponsorship = FactoryBot.build(:sponsorship, conference:, ticket_key: 'existing-key')
        sponsorship.save!
        expect(sponsorship.ticket_key).to eq('existing-key')
      end

      it 'generates unique ticket_keys' do
        keys = 5.times.map do
          FactoryBot.create(:sponsorship, conference:).ticket_key
        end
        expect(keys.uniq.length).to eq(5)
      end
    end
  end

  describe '#word_count' do
    it 'counts words in profile' do
      sponsorship = FactoryBot.build_stubbed(:sponsorship, conference:, profile: 'This is a test')
      expect(sponsorship.word_count).to eq(4)
    end

    it 'returns 0 for nil profile' do
      sponsorship = FactoryBot.build_stubbed(:sponsorship, conference:, profile: nil)
      expect(sponsorship.word_count).to eq(0)
    end

    it 'returns 0 for empty profile' do
      sponsorship = FactoryBot.build_stubbed(:sponsorship, conference:, profile: '')
      expect(sponsorship.word_count).to eq(0)
    end

    it 'counts words correctly with multiple spaces' do
      sponsorship = FactoryBot.build_stubbed(:sponsorship, conference:, profile: 'This   is    a    test')
      expect(sponsorship.word_count).to eq(4)
    end
  end

  describe '#total_number_of_attendees' do
    it 'returns sum of plan guests and additional attendees when active' do
      sponsorship = FactoryBot.create(:sponsorship, conference:, plan:, number_of_additional_attendees: 2)
      sponsorship.update!(accepted_at: Time.current)
      expect(sponsorship.total_number_of_attendees).to eq(5) # 3 from plan + 2 additional
    end

    it 'returns 0 when not active' do
      sponsorship = FactoryBot.build_stubbed(:sponsorship, conference:, plan:, number_of_additional_attendees: 2)
      expect(sponsorship.total_number_of_attendees).to eq(0)
    end

    it 'handles nil additional attendees' do
      sponsorship = FactoryBot.create(:sponsorship, conference:, plan:)
      sponsorship.update!(accepted_at: Time.current)
      expect(sponsorship.total_number_of_attendees).to eq(3)
    end

    it 'handles nil plan' do
      sponsorship = FactoryBot.create(:sponsorship, conference:)
      sponsorship.update!(accepted_at: Time.current)
      expect(sponsorship.total_number_of_attendees).to eq(0)
    end
  end

  describe '#total_number_of_booth_staff' do
    it 'returns 3 when active and booth_assigned' do
      sponsorship = FactoryBot.create(:sponsorship, conference:, plan:, booth_assigned: true)
      sponsorship.update!(accepted_at: Time.current)
      expect(sponsorship.total_number_of_booth_staff).to eq(3)
    end

    it 'returns 0 when not active' do
      sponsorship = FactoryBot.build_stubbed(:sponsorship, conference:, plan:, booth_assigned: true)
      expect(sponsorship.total_number_of_booth_staff).to eq(0)
    end

    it 'returns 0 when not booth_assigned' do
      sponsorship = FactoryBot.create(:sponsorship, conference:, plan:, booth_assigned: false)
      sponsorship.update!(accepted_at: Time.current)
      expect(sponsorship.total_number_of_booth_staff).to eq(0)
    end
  end

  describe '#to_param' do
    it 'returns id as string' do
      sponsorship = FactoryBot.build_stubbed(:sponsorship, conference:)
      expect(sponsorship.to_param).to eq(sponsorship.id.to_s)
    end
  end

  describe 'EditingHistoryTarget concern' do
    it 'creates editing history on save' do
      sponsorship = FactoryBot.build(:sponsorship, conference:)
      expect {
        sponsorship.save!
      }.to change { SponsorshipEditingHistory.count }.by(1)
    end

    it 'creates editing history on update' do
      sponsorship = FactoryBot.create(:sponsorship, conference:)
      initial_count = sponsorship.editing_histories.count

      sponsorship.update!(name: 'Updated Name')
      expect(sponsorship.editing_histories.count).to eq(initial_count + 1)
    end

    it 'records staff in editing history when set' do
      staff = FactoryBot.create(:staff)
      sponsorship = FactoryBot.build(:sponsorship, conference:)
      sponsorship.staff = staff
      sponsorship.save!

      expect(sponsorship.editing_histories.first.staff).to eq(staff)
    end
  end

  describe '#to_h_for_history' do
    it 'returns hash with key attributes' do
      sponsorship = FactoryBot.create(:sponsorship, conference:, plan:)
      sponsorship.update!(accepted_at: Time.current)

      hash = sponsorship.to_h_for_history
      expect(hash['name']).to eq(sponsorship.name)
      expect(hash['url']).to eq(sponsorship.url)
      expect(hash['profile']).to eq(sponsorship.profile)
      expect(hash['plan_id']).to eq(plan.id)
      expect(hash['plan_name']).to eq(plan.name)
      expect(hash['accepted_at']).to be_present
    end

    it 'includes fallback_option' do
      sponsorship = FactoryBot.create(:sponsorship, conference:, plan:, fallback_option: 'option1')

      hash = sponsorship.to_h_for_history
      expect(hash['fallback_option']).to eq('option1')
    end

    it 'includes withdrawn_at when present' do
      sponsorship = FactoryBot.create(:sponsorship, conference:)
      sponsorship.update!(withdrawn_at: Time.current)

      hash = sponsorship.to_h_for_history
      expect(hash['withdrawn_at']).to be_present
    end

    it 'does not include withdrawn_at when nil' do
      sponsorship = FactoryBot.create(:sponsorship, conference:)

      hash = sponsorship.to_h_for_history
      expect(hash.key?('withdrawn_at')).to be false
    end
  end
end
