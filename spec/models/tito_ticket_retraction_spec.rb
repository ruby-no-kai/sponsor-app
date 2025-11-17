require 'rails_helper'

RSpec.describe TitoTicketRetraction, type: :model do
  let(:conference) { FactoryBot.create(:conference, tito_slug: 'rubykaigi/2025') }
  let(:plan) { FactoryBot.create(:plan, conference:) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:) }

  describe 'associations' do
    it 'belongs to conference' do
      retraction = FactoryBot.build(:tito_ticket_retraction, sponsorship:)
      expect(retraction.conference).to eq(conference)
    end

    it 'belongs to sponsorship' do
      retraction = FactoryBot.build(:tito_ticket_retraction, sponsorship:)
      expect(retraction.sponsorship).to eq(sponsorship)
    end
  end

  describe 'validations' do
    let(:valid_tito_registration) do
      {
        'reference' => 'ABC123',
        'slug' => 'john-doe-abc123',
        'free' => true,
        'paid' => false,
        'refunded' => false,
        'partially_refunded' => false,
        'cancelled' => false,
        'tickets' => [
          {
            'release_id' => 'rel_1',
            'discount_code_used' => 'CODE'
          }
        ]
      }
    end

    it 'validates presence of reason' do
      retraction = FactoryBot.build(:tito_ticket_retraction, sponsorship:, reason: nil, tito_registration: valid_tito_registration, tito_registration_id: 'reg_1')
      expect(retraction).not_to be_valid
      expect(retraction.errors[:reason]).to be_present
    end

    it 'validates presence of tito_registration' do
      retraction = FactoryBot.build(:tito_ticket_retraction, sponsorship:, tito_registration: nil, tito_registration_id: 'reg_1')
      expect(retraction).not_to be_valid
      expect(retraction.errors[:tito_registration]).to be_present
    end

    it 'validates presence of tito_registration_id' do
      retraction = FactoryBot.build(:tito_ticket_retraction, sponsorship:, tito_registration: valid_tito_registration, tito_registration_id: nil)
      expect(retraction).not_to be_valid
      expect(retraction.errors[:tito_registration_id]).to be_present
    end

    describe 'validate_retractable on create' do
      context 'when retractable' do
        let(:tito_discount_code) { FactoryBot.create(:tito_discount_code, sponsorship:, code: 'SPONSOR2025') }

        before do
          tito_discount_code
        end

        it 'is valid' do
          retraction = FactoryBot.build(:tito_ticket_retraction, :with_tito_registration, sponsorship:)
          expect(retraction).to be_valid
        end
      end

      context 'when not retractable (paid ticket)' do
        let(:tito_discount_code) { FactoryBot.create(:tito_discount_code, sponsorship:, code: 'SPONSOR2025') }

        before do
          tito_discount_code
        end

        it 'is invalid' do
          retraction = FactoryBot.build(:tito_ticket_retraction, :paid, sponsorship:)
          expect(retraction).not_to be_valid
          expect(retraction.errors[:tito_registration]).to be_present
        end
      end

      context 'when not retractable (invalid discount code)' do
        let(:tito_discount_code) { FactoryBot.create(:tito_discount_code, sponsorship:, code: 'SPONSOR2025') }

        before do
          tito_discount_code
        end

        it 'is invalid' do
          retraction = FactoryBot.build(:tito_ticket_retraction, :invalid_discount_code, sponsorship:)
          expect(retraction).not_to be_valid
          expect(retraction.errors[:tito_registration]).to be_present
        end
      end
    end
  end

  describe '.prepare' do
    let(:mock_api) { instance_double(TitoApi) }
    let(:tito_registration_id) { 'reg_123' }
    let(:api_response) do
      {
        registration: {
          'reference' => 'ABC123',
          'slug' => 'john-doe-abc123',
          'free' => true,
          'paid' => false,
          'refunded' => false,
          'partially_refunded' => false,
          'cancelled' => false,
          'tickets' => [
            {
              'release_id' => 'rel_1',
              'discount_code_used' => 'SPONSOR2025'
            }
          ]
        }
      }
    end

    before do
      allow(TitoApi).to receive(:new).and_return(mock_api)
      allow(mock_api).to receive(:get_registration).and_return(api_response)
    end

    it 'creates a new retraction instance with proper attributes' do
      retraction = described_class.prepare(sponsorship, tito_registration_id)

      expect(retraction).to be_a(TitoTicketRetraction)
      expect(retraction.sponsorship).to eq(sponsorship)
      expect(retraction.conference).to eq(conference)
      expect(retraction.tito_registration_id).to eq('reg_123')
      expect(retraction.completed).to be false
      expect(retraction).to be_new_record
    end

    it 'fetches and sets tito_registration data' do
      retraction = described_class.prepare(sponsorship, tito_registration_id)

      expect(retraction.tito_registration).to eq(api_response[:registration])
      expect(mock_api).to have_received(:get_registration).with(
        'rubykaigi/2025',
        'reg_123',
        'expand' => 'tickets'
      )
    end
  end

  describe '#refresh_tito_registration' do
    let(:retraction) { FactoryBot.build(:tito_ticket_retraction, sponsorship:, tito_registration_id: 'reg_123') }
    let(:mock_api) { instance_double(TitoApi) }
    let(:api_response) do
      {
        registration: {
          'reference' => 'XYZ789',
          'slug' => 'jane-smith-xyz789',
          'free' => true,
          'paid' => false,
          'refunded' => false,
          'partially_refunded' => false,
          'cancelled' => false,
          'tickets' => [
            {
              'release_id' => 'rel_2',
              'discount_code_used' => 'SPONSOR2025'
            }
          ]
        }
      }
    end

    it 'fetches and updates tito_registration data' do
      expect(mock_api).to receive(:get_registration).with(
        'rubykaigi/2025',
        'reg_123',
        'expand' => 'tickets'
      ).and_return(api_response)

      result = retraction.refresh_tito_registration(api: mock_api)

      expect(result).to eq(retraction)
      expect(retraction.tito_registration).to eq(api_response[:registration])
    end
  end

  describe '#preconditions' do
    context 'when tito_registration is nil' do
      let(:retraction) { FactoryBot.build(:tito_ticket_retraction, sponsorship:, tito_registration: nil) }

      it 'returns nil' do
        expect(retraction.preconditions).to be_nil
      end
    end

    context 'with valid registration data' do
      let!(:tito_discount_code) { FactoryBot.create(:tito_discount_code, sponsorship:, code: 'SPONSOR2025') }
      let(:retraction) { FactoryBot.build(:tito_ticket_retraction, :with_tito_registration, sponsorship:) }

      it 'returns preconditions hash' do
        preconditions = retraction.preconditions

        expect(preconditions).to be_a(Hash)
        expect(preconditions[:free]).to be true
        expect(preconditions[:paid]).to be false
        expect(preconditions[:refunded]).to be false
        expect(preconditions[:partially_refunded]).to be false
        expect(preconditions[:cancelled]).to be false
        expect(preconditions[:ticket_release_count]).to eq(1)
        expect(preconditions[:ticket_discount_code_count]).to eq(1)
        expect(preconditions[:discount_codes_used]).to eq(['SPONSOR2025'])
        expect(preconditions[:invalid_discount_codes]).to eq([])
        expect(preconditions[:valid_discount_code_used]).to be true
      end
    end

    context 'with multiple releases' do
      let!(:tito_discount_code) { FactoryBot.create(:tito_discount_code, sponsorship:, code: 'SPONSOR2025') }
      let(:retraction) { FactoryBot.build(:tito_ticket_retraction, :multiple_releases, sponsorship:) }

      it 'counts multiple releases' do
        preconditions = retraction.preconditions

        expect(preconditions[:ticket_release_count]).to eq(2)
        expect(preconditions[:ticket_discount_code_count]).to eq(1)
      end
    end

    context 'with invalid discount code' do
      let!(:tito_discount_code) { FactoryBot.create(:tito_discount_code, sponsorship:, code: 'SPONSOR2025') }
      let(:retraction) { FactoryBot.build(:tito_ticket_retraction, :invalid_discount_code, sponsorship:) }

      it 'identifies invalid discount codes' do
        preconditions = retraction.preconditions

        expect(preconditions[:discount_codes_used]).to eq(['INVALID_CODE'])
        expect(preconditions[:invalid_discount_codes]).to eq(['INVALID_CODE'])
        expect(preconditions[:valid_discount_code_used]).to be false
      end
    end
  end

  describe '#retractable?' do
    context 'when preconditions is nil' do
      let(:retraction) { FactoryBot.build(:tito_ticket_retraction, sponsorship:, tito_registration: nil) }

      it 'returns false' do
        expect(retraction.retractable?).to be false
      end
    end

    context 'when all conditions are met' do
      let!(:tito_discount_code) { FactoryBot.create(:tito_discount_code, sponsorship:, code: 'SPONSOR2025') }
      let(:retraction) { FactoryBot.build(:tito_ticket_retraction, :with_tito_registration, sponsorship:) }

      it 'returns true' do
        expect(retraction.retractable?).to be true
      end
    end

    context 'when ticket is paid' do
      let!(:tito_discount_code) { FactoryBot.create(:tito_discount_code, sponsorship:, code: 'SPONSOR2025') }
      let(:retraction) { FactoryBot.build(:tito_ticket_retraction, :paid, sponsorship:) }

      it 'returns false' do
        expect(retraction.retractable?).to be false
      end
    end

    context 'when ticket is cancelled' do
      let!(:tito_discount_code) { FactoryBot.create(:tito_discount_code, sponsorship:, code: 'SPONSOR2025') }
      let(:retraction) { FactoryBot.build(:tito_ticket_retraction, :cancelled, sponsorship:) }

      it 'returns false' do
        expect(retraction.retractable?).to be false
      end
    end

    context 'when multiple releases' do
      let!(:tito_discount_code) { FactoryBot.create(:tito_discount_code, sponsorship:, code: 'SPONSOR2025') }
      let(:retraction) { FactoryBot.build(:tito_ticket_retraction, :multiple_releases, sponsorship:) }

      it 'returns false' do
        expect(retraction.retractable?).to be false
      end
    end

    context 'when invalid discount code' do
      let!(:tito_discount_code) { FactoryBot.create(:tito_discount_code, sponsorship:, code: 'SPONSOR2025') }
      let(:retraction) { FactoryBot.build(:tito_ticket_retraction, :invalid_discount_code, sponsorship:) }

      it 'returns false' do
        expect(retraction.retractable?).to be false
      end
    end
  end

  describe '#order_reference' do
    context 'with tito_registration' do
      let(:retraction) { FactoryBot.build(:tito_ticket_retraction, :with_tito_registration, sponsorship:) }

      it 'returns the reference' do
        expect(retraction.order_reference).to eq('ABC123')
      end
    end

    context 'without tito_registration' do
      let(:retraction) { FactoryBot.build(:tito_ticket_retraction, sponsorship:, tito_registration: nil) }

      it 'returns nil' do
        expect(retraction.order_reference).to be_nil
      end
    end
  end

  describe '#tito_admin_url' do
    let(:retraction) { FactoryBot.build(:tito_ticket_retraction, :with_tito_registration, sponsorship:) }

    it 'returns the Tito admin URL' do
      expected_url = 'https://dashboard.tito.io/rubykaigi/2025/registrations/john-doe-abc123'
      expect(retraction.tito_admin_url).to eq(expected_url)
    end

    context 'with special characters in slug' do
      let(:retraction) do
        r = FactoryBot.build(:tito_ticket_retraction, :with_tito_registration, sponsorship:)
        r.tito_registration['slug'] = 'john+doe@example.com'
        r
      end

      it 'properly encodes the slug' do
        expect(retraction.tito_admin_url).to include('john%2Bdoe%40example.com')
      end
    end
  end

  describe '#ticket_release_slugs' do
    let(:tito_cached_release) do
      FactoryBot.create(:tito_cached_release,
        conference:,
        tito_release_id: 'rel_1',
        tito_release_slug: 'early-bird'
      )
    end

    before do
      tito_cached_release
    end

    context 'with matching cached release' do
      let(:retraction) { FactoryBot.build(:tito_ticket_retraction, :with_tito_registration, sponsorship:) }

      it 'returns the release slugs' do
        expect(retraction.ticket_release_slugs).to eq(['early-bird'])
      end
    end

    context 'without matching cached release' do
      let(:retraction) do
        r = FactoryBot.build(:tito_ticket_retraction, :with_tito_registration, sponsorship:)
        r.tito_registration['tickets'][0]['release_id'] = 'rel_999'
        r
      end

      it 'returns array with nil' do
        expect(retraction.ticket_release_slugs).to eq([nil])
      end
    end

    context 'with multiple releases' do
      let(:tito_cached_release_2) do
        FactoryBot.create(:tito_cached_release,
          conference:,
          tito_release_id: 'rel_2',
          tito_release_slug: 'regular'
        )
      end

      before do
        tito_cached_release_2
      end

      let(:retraction) { FactoryBot.build(:tito_ticket_retraction, :multiple_releases, sponsorship:) }

      it 'returns unique release slugs' do
        expect(retraction.ticket_release_slugs).to contain_exactly('early-bird', 'regular')
      end
    end

    context 'without conference' do
      let(:retraction) do
        r = FactoryBot.build(:tito_ticket_retraction, :with_tito_registration, sponsorship:)
        r.conference = nil
        r
      end

      it 'returns array with nil' do
        expect(retraction.ticket_release_slugs).to eq([nil])
      end
    end
  end
end
