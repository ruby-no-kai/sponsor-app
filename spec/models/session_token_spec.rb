require 'rails_helper'

RSpec.describe SessionToken, type: :model do
  let(:conference) { FactoryBot.create(:conference) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:) }

  describe 'validations' do
    it 'auto-generates handle when not provided' do
      token = FactoryBot.build_stubbed(:session_token, expires_at: 1.day.from_now)
      token.handle = nil
      token.valid?
      expect(token.handle).not_to be_nil
    end

    it 'auto-generates expires_at when not provided' do
      token = FactoryBot.build_stubbed(:session_token)
      token.expires_at = nil
      token.valid?
      expect(token.expires_at).not_to be_nil
    end
  end

  describe 'callbacks' do
    it 'generates handle when not provided' do
      token = FactoryBot.create(:session_token)
      expect(token.handle).to be_present
      expect(token.handle.length).to be > 50
    end

    it 'does not overwrite existing handle' do
      token = FactoryBot.build(:session_token, handle: 'existing-handle')
      token.save!
      expect(token.handle).to eq('existing-handle')
    end

    it 'sets default expires_at to 3 months from now' do
      before_time = 3.months.from_now
      token = FactoryBot.create(:session_token)
      after_time = 3.months.from_now
      expect(token.expires_at).to be_between(before_time, after_time)
    end

    it 'does not overwrite existing expires_at' do
      custom_time = 1.week.from_now
      token = FactoryBot.build(:session_token, expires_at: custom_time)
      token.save!
      expect(token.expires_at.to_i).to eq(custom_time.to_i)
    end

    it 'generates unique handles' do
      handles = 5.times.map { FactoryBot.create(:session_token).handle }
      expect(handles.uniq.length).to eq(5)
    end
  end

  describe 'scopes' do
    describe '.active' do
      let!(:active_token) { FactoryBot.create(:session_token, expires_at: 1.day.from_now) }
      let!(:expired_token) { FactoryBot.create(:session_token, :expired) }

      it 'includes tokens that have not expired' do
        expect(SessionToken.active).to include(active_token)
      end

      it 'excludes expired tokens' do
        expect(SessionToken.active).not_to include(expired_token)
      end
    end
  end

  describe '#expired?' do
    it 'returns false when not yet expired' do
      token = FactoryBot.build_stubbed(:session_token, expires_at: 1.day.from_now)
      expect(token.expired?).to be false
    end

    it 'returns true when expired' do
      token = FactoryBot.build_stubbed(:session_token, :expired)
      expect(token.expired?).to be true
    end

    it 'accepts at parameter' do
      token = FactoryBot.build_stubbed(:session_token, expires_at: 1.day.from_now)
      expect(token.expired?(at: 2.days.from_now)).to be true
      expect(token.expired?(at: Time.zone.now)).to be false
    end
  end

  describe '#contacts' do
    it 'returns empty relation when email is nil' do
      token = FactoryBot.create(:session_token)
      expect(token.contacts).to be_empty
    end

    it 'finds contacts with matching email' do
      sponsorship.contact.update!(email: 'test@example.com')

      token = FactoryBot.create(:session_token, email: 'test@example.com')
      expect(token.contacts).to include(sponsorship.contact)
    end

    it 'only returns primary contacts' do
      FactoryBot.create(:contact, sponsorship:, kind: :billing, email: 'test@example.com')

      token = FactoryBot.create(:session_token, email: 'test@example.com')
      expect(token.contacts.where(kind: :billing).count).to eq(0)
    end
  end

  describe '#sponsorships' do
    it 'returns sponsorships associated with contacts' do
      sponsorship.contact.update!(email: 'test@example.com')

      token = FactoryBot.create(:session_token, email: 'test@example.com')
      expect(token.sponsorships).to include(sponsorship)
    end

    it 'returns empty array when no contacts' do
      token = FactoryBot.create(:session_token)
      expect(token.sponsorships).to eq([])
    end

    it 'sorts sponsorships by id' do
      sponsorship2 = FactoryBot.create(:sponsorship, conference:)

      sponsorship.contact.update!(email: 'shared@example.com')
      sponsorship2.contact.update!(email: 'shared@example.com')

      token = FactoryBot.create(:session_token, email: 'shared@example.com')
      expect(token.sponsorships.first.id).to be < token.sponsorships.last.id
    end
  end

  describe '#sponsorship_ids' do
    it 'returns ids of associated sponsorships' do
      sponsorship.contact.update!(email: 'test@example.com')

      token = FactoryBot.create(:session_token, email: 'test@example.com')
      expect(token.sponsorship_ids).to eq([sponsorship.id])
    end

    it 'returns empty array when no sponsorships' do
      token = FactoryBot.create(:session_token)
      expect(token.sponsorship_ids).to eq([])
    end
  end

  describe '#to_param' do
    it 'returns handle' do
      token = FactoryBot.build_stubbed(:session_token)
      expect(token.to_param).to eq(token.handle)
    end
  end
end
