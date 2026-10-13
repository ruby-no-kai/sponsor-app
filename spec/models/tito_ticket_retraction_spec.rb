# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/NestedGroups
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
            'discount_code_used' => 'CODE',
          },
        ],
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
              'discount_code_used' => 'SPONSOR2025',
            },
          ],
        },
      }
    end

    before do
      allow(TitoApi).to receive(:new).and_return(mock_api)
      allow(mock_api).to receive(:get_registration).and_return(api_response)
    end

    it 'creates a new retraction instance with proper attributes' do
      retraction = described_class.prepare(sponsorship, tito_registration_id)

      expect(retraction).to be_a(described_class)
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
        'expand' => 'tickets',
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
              'discount_code_used' => 'SPONSOR2025',
            },
          ],
        },
      }
    end

    it 'fetches and updates tito_registration data' do
      allow(mock_api).to receive(:get_registration).with(
        'rubykaigi/2025',
        'reg_123',
        'expand' => 'tickets',
      ).and_return(api_response)

      result = retraction.refresh_tito_registration(api: mock_api)

      expect(mock_api).to have_received(:get_registration).with(
        'rubykaigi/2025',
        'reg_123',
        'expand' => 'tickets',
      )
      expect(result).to eq(retraction)
      expect(retraction.tito_registration).to eq(api_response[:registration])
    end

    it 'raises when the conference has no tito_slug' do
      conference.update!(tito_slug: nil)
      allow(mock_api).to receive(:get_registration)

      expect { retraction.refresh_tito_registration(api: mock_api) }.to raise_error(Must::Violation)
      expect(mock_api).not_to have_received(:get_registration)
    end
  end

  describe '#registration_maybe' do
    %i(with_tito_registration paid cancelled multiple_releases invalid_discount_code).each do |trait|
      it "decodes the #{trait} trait" do
        retraction = FactoryBot.build(:tito_ticket_retraction, trait, sponsorship:)
        raw = retraction.tito_registration

        expect(retraction.registration_maybe).to have_attributes(
          reference: raw.fetch('reference'),
          slug: raw.fetch('slug'),
          free: raw.fetch('free'),
          paid: raw.fetch('paid'),
          refunded: raw.fetch('refunded'),
          partially_refunded: raw.fetch('partially_refunded'),
          cancelled: raw.fetch('cancelled'),
        )
        expect(retraction.registration_maybe.tickets.map { |t| [t.release_id, t.discount_code] }).to eq(
          raw.fetch('tickets').map { |t| [t.fetch('release_id'), t.fetch('discount_code_used')] },
        )
      end
    end

    it 'resolves release slugs from the conference cached releases' do
      FactoryBot.create(:tito_cached_release, conference:, tito_release_id: 'rel_1', tito_release_slug: 'sponsor')
      retraction = FactoryBot.build(:tito_ticket_retraction, :with_tito_registration, sponsorship:)

      expect(retraction.registration_maybe.tickets.sole.release_slug).to eq('sponsor')
    end

    it 'is nil without tito_registration' do
      retraction = FactoryBot.build(:tito_ticket_retraction, sponsorship:, tito_registration: nil)

      expect(retraction.registration_maybe).to be_nil
    end
  end

  describe '#registration' do
    it 'raises without tito_registration' do
      retraction = FactoryBot.build(:tito_ticket_retraction, sponsorship:, tito_registration: nil)

      expect { retraction.registration }.to raise_error(Must::Violation)
    end
  end

  describe '#preconditions' do
    context 'when tito_registration is nil' do
      let(:retraction) { FactoryBot.build(:tito_ticket_retraction, sponsorship:, tito_registration: nil) }

      it 'returns nil' do
        expect(retraction.preconditions).to be_nil
      end
    end

    context 'when sponsorship is nil' do
      let(:retraction) { FactoryBot.build(:tito_ticket_retraction, :with_tito_registration, sponsorship: nil, conference:) }

      it 'reports no valid discount codes instead of raising' do
        expect(retraction.preconditions).to have_attributes(valid_discount_code_used: false)
        expect(retraction).not_to be_retractable
      end

      it 'fails validation on create' do
        expect(retraction).not_to be_valid
      end
    end

    context 'with valid registration data' do
      let!(:tito_discount_code) { FactoryBot.create(:tito_discount_code, sponsorship:, code: 'SPONSOR2025') } # rubocop:disable RSpec/LetSetup
      let(:retraction) { FactoryBot.build(:tito_ticket_retraction, :with_tito_registration, sponsorship:) }

      it 'returns the preconditions' do
        expect(retraction.preconditions).to be_a(described_class::Preconditions).and have_attributes(
          free: true,
          paid: false,
          refunded: false,
          partially_refunded: false,
          cancelled: false,
          ticket_release_count: 1,
          ticket_discount_code_count: 1,
          discount_codes_used: ['SPONSOR2025'],
          invalid_discount_codes: [],
          valid_discount_code_used: true,
        )
        expect(retraction.preconditions).to be_satisfied
      end

      it 'prints every member when inspected' do
        expect(retraction.preconditions.inspect).to include('free=true', 'ticket_release_count=1', 'discount_codes_used=["SPONSOR2025"]', 'valid_discount_code_used=true')
      end
    end

    context 'with multiple releases' do
      let!(:tito_discount_code) { FactoryBot.create(:tito_discount_code, sponsorship:, code: 'SPONSOR2025') } # rubocop:disable RSpec/LetSetup
      let(:retraction) { FactoryBot.build(:tito_ticket_retraction, :multiple_releases, sponsorship:) }

      it 'counts multiple releases' do
        expect(retraction.preconditions).to have_attributes(ticket_release_count: 2, ticket_discount_code_count: 1)
      end
    end

    context 'with invalid discount code' do
      let!(:tito_discount_code) { FactoryBot.create(:tito_discount_code, sponsorship:, code: 'SPONSOR2025') } # rubocop:disable RSpec/LetSetup
      let(:retraction) { FactoryBot.build(:tito_ticket_retraction, :invalid_discount_code, sponsorship:) }

      it 'identifies invalid discount codes' do
        expect(retraction.preconditions).to have_attributes(
          discount_codes_used: ['INVALID_CODE'],
          invalid_discount_codes: ['INVALID_CODE'],
          valid_discount_code_used: false,
        )
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
      let!(:tito_discount_code) { FactoryBot.create(:tito_discount_code, sponsorship:, code: 'SPONSOR2025') } # rubocop:disable RSpec/LetSetup
      let(:retraction) { FactoryBot.build(:tito_ticket_retraction, :with_tito_registration, sponsorship:) }

      it 'returns true' do
        expect(retraction.retractable?).to be true
      end
    end

    context 'when ticket is paid' do
      let!(:tito_discount_code) { FactoryBot.create(:tito_discount_code, sponsorship:, code: 'SPONSOR2025') } # rubocop:disable RSpec/LetSetup
      let(:retraction) { FactoryBot.build(:tito_ticket_retraction, :paid, sponsorship:) }

      it 'returns false' do
        expect(retraction.retractable?).to be false
      end
    end

    context 'when the paid flag is missing' do
      let!(:tito_discount_code) { FactoryBot.create(:tito_discount_code, sponsorship:, code: 'SPONSOR2025') } # rubocop:disable RSpec/LetSetup
      let(:retraction) do
        FactoryBot.build(:tito_ticket_retraction, :with_tito_registration, sponsorship:).tap do |r|
          r.tito_registration = r.tito_registration.except('paid')
        end
      end

      it 'returns false' do
        expect(retraction.retractable?).to be false
      end
    end

    context 'when ticket is cancelled' do
      let!(:tito_discount_code) { FactoryBot.create(:tito_discount_code, sponsorship:, code: 'SPONSOR2025') } # rubocop:disable RSpec/LetSetup
      let(:retraction) { FactoryBot.build(:tito_ticket_retraction, :cancelled, sponsorship:) }

      it 'returns false' do
        expect(retraction.retractable?).to be false
      end
    end

    context 'when multiple releases' do
      let!(:tito_discount_code) { FactoryBot.create(:tito_discount_code, sponsorship:, code: 'SPONSOR2025') } # rubocop:disable RSpec/LetSetup
      let(:retraction) { FactoryBot.build(:tito_ticket_retraction, :multiple_releases, sponsorship:) }

      it 'returns false' do
        expect(retraction.retractable?).to be false
      end
    end

    context 'when invalid discount code' do
      let!(:tito_discount_code) { FactoryBot.create(:tito_discount_code, sponsorship:, code: 'SPONSOR2025') } # rubocop:disable RSpec/LetSetup
      let(:retraction) { FactoryBot.build(:tito_ticket_retraction, :invalid_discount_code, sponsorship:) }

      it 'returns false' do
        expect(retraction.retractable?).to be false
      end
    end
  end

  describe '#registered_through_sponsorship?' do
    let(:registration) do
      {
        'id' => 101,
        'source' => sponsorship.tito_source_code,
        'discount_code' => 'SPONSOR2025',
        'tickets' => [{'discount_code_used' => 'SPONSOR2025'}],
      }
    end

    before { FactoryBot.create(:tito_discount_code, sponsorship:, code: 'SPONSOR2025') }

    def retraction_of(registration)
      described_class.new(sponsorship:, conference:, tito_registration_id: '101', tito_registration: registration)
    end

    it 'holds for a registration under the source, made with its codes' do
      expect(retraction_of(registration)).to be_registered_through_sponsorship
    end

    it 'fails under another source' do
      expect(retraction_of(registration.merge('source' => 'ss_0'))).not_to be_registered_through_sponsorship
    end

    it 'fails for a registration made with another code' do
      expect(retraction_of(registration.merge('discount_code' => 'OTHER'))).not_to be_registered_through_sponsorship
    end

    it 'fails for a registration holding a ticket of another code' do
      tickets = [*registration.fetch('tickets'), {'discount_code_used' => 'OTHER'}]

      expect(retraction_of(registration.merge('tickets' => tickets))).not_to be_registered_through_sponsorship
    end

    it 'fails for a registration of another ID' do
      expect(retraction_of(registration.merge('id' => 999))).not_to be_registered_through_sponsorship
    end

    it 'fails before the registration is loaded' do
      expect(retraction_of(nil)).not_to be_registered_through_sponsorship
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

    context 'without a conference' do
      let(:retraction) { FactoryBot.build(:tito_ticket_retraction, :with_tito_registration, sponsorship:, conference: nil) }

      it 'raises' do
        expect { retraction.tito_admin_url }.to raise_error(Must::Violation)
      end
    end
  end

  describe '#ticket_release_slugs' do
    let(:tito_cached_release) do
      FactoryBot.create(
        :tito_cached_release,
        conference:,
        tito_release_id: 'rel_1',
        tito_release_slug: 'early-bird',
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
        FactoryBot.create(
          :tito_cached_release,
          conference:,
          tito_release_id: 'rel_2',
          tito_release_slug: 'regular',
        )
      end
      let(:retraction) { FactoryBot.build(:tito_ticket_retraction, :multiple_releases, sponsorship:) }

      before do
        tito_cached_release_2
      end

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

  describe '#registration_email' do
    it 'returns the email of the stored registration' do
      retraction = described_class.new(sponsorship:, conference:, tito_registration: {'email' => 'registrant@example.invalid'})

      expect(retraction.registration_email).to eq('registrant@example.invalid')
    end

    it 'returns nil before the registration is loaded' do
      expect(described_class.new(sponsorship:, conference:).registration_email).to be_nil
    end
  end

  describe '#affected_tickets' do
    before { FactoryBot.create(:tito_cached_release, conference:, tito_release_id: '11', tito_release_slug: 'sponsor') }

    it 'returns each stored ticket with the slug of its cached release' do
      tickets = [
        {'reference' => 'T1', 'release_id' => 11, 'email' => 'one@example.invalid'},
        {'reference' => 'T2', 'release_id' => 99},
      ]
      retraction = described_class.new(sponsorship:, conference:, tito_registration: {'tickets' => tickets})

      expect(retraction.affected_tickets.map { [it.reference, it.release_slug, it.email] }).to eq([
        ['T1', 'sponsor', 'one@example.invalid'],
        ['T2', nil, nil],
      ])
    end

    it 'returns none before the registration is loaded' do
      expect(described_class.new(sponsorship:, conference:).affected_tickets).to eq([])
    end
  end
end
# rubocop:enable RSpec/NestedGroups
