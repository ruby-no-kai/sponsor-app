require 'rails_helper'

RSpec.describe Contact, type: :model do
  let(:sponsorship) { FactoryBot.create(:sponsorship) }

  describe 'validations' do





    describe 'email_cc format validation' do
      it 'accepts blank email_cc' do
        contact = FactoryBot.build(:contact, email_cc: '')
        expect(contact).to be_valid
      end

      it 'accepts nil email_cc' do
        contact = FactoryBot.build(:contact, email_cc: nil)
        expect(contact).to be_valid
      end

      it 'accepts single email' do
        contact = FactoryBot.build(:contact, email_cc: 'cc@example.com')
        expect(contact).to be_valid
      end

      it 'accepts comma-separated emails' do
        contact = FactoryBot.build(:contact, email_cc: 'cc1@example.com, cc2@example.com')
        expect(contact).to be_valid
      end

      it 'accepts semicolon-separated emails' do
        contact = FactoryBot.build(:contact, email_cc: 'cc1@example.com; cc2@example.com')
        expect(contact).to be_valid
      end

      it 'rejects invalid format' do
        contact = FactoryBot.build(:contact, email_cc: 'not-an-email')
        expect(contact).not_to be_valid
        expect(contact.errors[:email_cc]).to be_present
      end
    end

    describe 'validate_email_ccs custom validation' do
      it 'validates each email contains @' do
        contact = FactoryBot.build(:contact, email_cc: 'valid@example.com')
        expect(contact).to be_valid
      end

      it 'rejects emails without @' do
        contact = FactoryBot.build(:contact, email_cc: 'invalid.com')
        expect(contact).not_to be_valid
        expect(contact.errors[:email_cc]).to include('is invalid')
      end

      it 'validates multiple emails' do
        contact = FactoryBot.build(:contact, email_cc: 'valid1@example.com, valid2@example.com')
        expect(contact).to be_valid
      end

      it 'rejects if any email in list is invalid' do
        contact = FactoryBot.build(:contact, email_cc: 'valid@example.com, invalid')
        expect(contact).not_to be_valid
        expect(contact.errors[:email_cc]).to include('is invalid')
      end
    end
  end

  describe '#email_ccs' do
    it 'returns empty array when email_cc is nil' do
      contact = FactoryBot.build(:contact, email_cc: nil)
      expect(contact.email_ccs).to eq([])
    end

    it 'returns empty array when email_cc is empty string' do
      contact = FactoryBot.build(:contact, email_cc: '')
      expect(contact.email_ccs).to eq([])
    end

    it 'parses single email' do
      contact = FactoryBot.build(:contact, email_cc: 'test@example.com')
      expect(contact.email_ccs).to eq(['test@example.com'])
    end

    it 'parses comma-separated emails' do
      contact = FactoryBot.build(:contact, email_cc: 'test1@example.com, test2@example.com')
      expect(contact.email_ccs).to eq(['test1@example.com', 'test2@example.com'])
    end

    it 'parses semicolon-separated emails' do
      contact = FactoryBot.build(:contact, email_cc: 'test1@example.com; test2@example.com')
      expect(contact.email_ccs).to eq(['test1@example.com', 'test2@example.com'])
    end

    it 'handles mixed separators' do
      contact = FactoryBot.build(:contact, email_cc: 'test1@example.com, test2@example.com; test3@example.com')
      expect(contact.email_ccs).to eq(['test1@example.com', 'test2@example.com', 'test3@example.com'])
    end

    it 'strips leading/trailing whitespace and splits on comma' do
      contact = FactoryBot.build(:contact, email_cc: '  test1@example.com,test2@example.com  ')
      expect(contact.email_ccs).to eq(['test1@example.com', 'test2@example.com'])
    end

    it 'handles extra spaces between emails' do
      contact = FactoryBot.build(:contact, email_cc: 'test1@example.com,    test2@example.com')
      expect(contact.email_ccs).to eq(['test1@example.com', 'test2@example.com'])
    end
  end

  describe '#_keep' do
    it 'returns false for new records by default' do
      contact = FactoryBot.build(:contact, sponsorship:)
      expect(contact._keep).to be false
    end

    it 'returns true for persisted records by default' do
      contact = FactoryBot.create(:contact, sponsorship:, kind: :billing)
      expect(contact._keep).to be true
    end

    it 'can be set manually' do
      contact = FactoryBot.build(:contact, sponsorship:)
      contact._keep = true
      expect(contact._keep).to be true
    end

    it 'remembers manually set value' do
      sp = FactoryBot.create(:sponsorship)
      contact = FactoryBot.create(:contact, sponsorship: sp, kind: :billing)
      contact._keep = false
      expect(contact._keep).to be false
    end
  end
end
