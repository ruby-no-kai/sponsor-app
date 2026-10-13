# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PassRedemption do
  let(:conference) { FactoryBot.create(:conference, tito_slug: 'rubykaigi/2025') }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:) }

  describe PassRedemption::Registration do
    describe '.from_tito' do
      let(:releases) { {'11' => FactoryBot.build(:tito_cached_release, tito_release_id: '11', tito_release_slug: 'sponsor')} }
      let(:tito_registration) do
        {
          id: 1, slug: 'reg-abcd', reference: 'ABCD',
          discount_code: 'SPONSOR1', source: 'ss_1',
          email: 'attendee@example.invalid',
          state: 'complete',
          free: true, paid: false, cancelled: false, refunded: false, partially_refunded: false,
          tickets: [
            {
              id: 2, reference: 'ABCD-1',
              discount_code_used: 'SPONSOR1', release_id: 11,
              email: 'ticket@example.invalid',
              state: 'complete',
              void: false, assigned: true,
            },
          ],
        }
      end

      it "reads Tito's response with Symbol keys" do
        registration = described_class.from_tito(tito_registration, releases:)

        expect(registration).to have_attributes(
          id: 1, slug: 'reg-abcd', reference: 'ABCD',
          discount_code: 'SPONSOR1', source: 'ss_1',
          email: 'attendee@example.invalid',
          state: 'complete',
          free: true, paid: false, cancelled: false, refunded: false, partially_refunded: false,
        )
        expect(registration.tickets.sole).to have_attributes(
          id: 2, reference: 'ABCD-1',
          discount_code: 'SPONSOR1', release_id: '11', release_slug: 'sponsor',
          email: 'ticket@example.invalid',
          state: 'complete',
          void: false, assigned: true,
        )
      end

      it 'reads a stored copy with String keys' do
        expect(described_class.from_tito(tito_registration.deep_stringify_keys, releases:)).to eq(described_class.from_tito(tito_registration, releases:))
      end

      it 'leaves release_slug nil for a release missing from the index' do
        registration = described_class.from_tito(tito_registration, releases: {})

        expect(registration.tickets.sole).to have_attributes(release_id: '11', release_slug: nil)
      end

      it 'reads a registration without tickets' do
        registration = described_class.from_tito({'reference' => 'ABCD'}, releases:)

        expect(registration).to have_attributes(reference: 'ABCD', tickets: [])
      end
    end
  end

  describe PassRedemption::Collection do
    let!(:discount_code) { FactoryBot.create(:tito_discount_code, sponsorship:, code: 'SPONSOR1') }
    let!(:release) { FactoryBot.create(:tito_cached_release, conference:, tito_release_id: '11', tito_release_slug: 'sponsor') }
    let(:registration) do
      {
        id: 1,
        reference: 'ABCD',
        source: 'ss_1',
        discount_code: 'SPONSOR1',
        email: 'attendee@example.com',
        state: 'complete',
        free: true,
        paid: false,
        cancelled: false,
        refunded: false,
        partially_refunded: false,
        tickets: [
          {
            id: 2,
            reference: 'ABCD-1',
            discount_code_used: 'SPONSOR1',
            release_id: 11,
            email: 'attendee@example.com',
            state: 'complete',
            void: false,
            assigned: true,
          },
        ],
      }
    end

    let(:mixed_registration) do
      registration.merge(tickets: [*registration.fetch(:tickets), ticket('ABCD-2', discount_code_used: 'OTHER')])
    end

    def ticket(reference, discount_code_used:, release_id: 11)
      {id: 3, reference:, discount_code_used:, release_id:, email: 'other@example.invalid', state: 'complete', void: false, assigned: true}
    end

    def collection_of(*registrations, **)
      described_class.from_tito_registration_list({registrations:, meta: {total_pages: 1}}, **)
    end

    describe '.from_tito_registration_list' do
      it 'builds registrations from the Tito response' do
        collection = collection_of(registration, sponsorship:)

        expect(collection.registrations.size).to eq(1)
        reg = collection.registrations.first
        expect(reg.reference).to eq('ABCD')
        expect(collection.retractable?(reg)).to be true
        expect(reg.tickets.first.release_slug).to eq(release.tito_release_slug)
        expect(reg.tickets.first.discount_code).to eq(discount_code.code)
      end

      it 'drops registrations made with another discount code' do
        collection = collection_of(registration.merge(discount_code: 'OTHER'), sponsorship:)

        expect(collection.registrations).to be_empty
      end

      it 'keeps tickets made with another discount code on the registration' do
        expect(collection_of(mixed_registration, sponsorship:).registrations.sole.tickets.map(&:reference)).to eq(%w(ABCD-1 ABCD-2))
      end

      it 'raises when the response has more than one page' do
        expect do
          described_class.from_tito_registration_list(
            {registrations: [registration], meta: {total_pages: 2}},
            sponsorship:,
          )
        end.to raise_error(PassRedemption::PaginationNotSupported)
      end
    end

    describe '#tickets_for' do
      it "shows only the tickets made with the sponsorship's codes" do
        collection = collection_of(mixed_registration, sponsorship:)

        expect(collection.tickets_for(collection.registrations.sole).map(&:reference)).to eq(%w(ABCD-1))
      end

      it 'shows every ticket without a sponsorship' do
        collection = collection_of(mixed_registration, conference:)

        expect(collection.tickets_for(collection.registrations.sole).map(&:reference)).to eq(%w(ABCD-1 ABCD-2))
      end
    end

    describe '#holds_other_codes?' do
      it 'is true for a registration holding a ticket claimed with another code' do
        collection = collection_of(mixed_registration, sponsorship:)

        expect(collection.holds_other_codes?(collection.registrations.sole)).to be true
      end

      it 'is false for a registration of the sponsorship codes only' do
        collection = collection_of(registration, sponsorship:)

        expect(collection.holds_other_codes?(collection.registrations.sole)).to be false
      end

      it 'is false without a sponsorship' do
        collection = collection_of(mixed_registration, conference:)

        expect(collection.holds_other_codes?(collection.registrations.sole)).to be false
      end
    end

    describe '#retractable?' do
      it 'judges a registration on the shown tickets only' do
        collection = collection_of(mixed_registration, sponsorship:)

        expect(collection.retractable?(collection.registrations.sole)).to be true
      end

      it 'is false when the shown tickets span releases' do
        two_releases = registration.merge(tickets: [*registration.fetch(:tickets), ticket('ABCD-2', discount_code_used: 'SPONSOR1', release_id: 12)])
        collection = collection_of(two_releases, sponsorship:)

        expect(collection.retractable?(collection.registrations.sole)).to be false
      end

      it 'is false for a paid registration' do
        collection = collection_of(registration.merge(free: false, paid: true), sponsorship:)

        expect(collection.retractable?(collection.registrations.sole)).to be false
      end

      it 'is false for a registration without shown tickets' do
        collection = collection_of(registration.merge(tickets: [ticket('ABCD-2', discount_code_used: 'OTHER')]), sponsorship:)

        expect(collection.retractable?(collection.registrations.sole)).to be false
      end
    end
  end

  describe '.list_for_sponsorship' do
    let(:api) { instance_double(TitoApi, list_registrations: {registrations: [], meta: {total_pages: 1}}) }

    before do
      allow(TitoApi).to receive(:new).and_return(api)
    end

    it "lists registrations from the sponsorship's source" do
      TitoSource.create!(conference:, sponsorship:, tito_source_id: '1')

      expect(described_class.list_for_sponsorship(sponsorship).registrations).to be_empty
      expect(api).to have_received(:list_registrations).with(
        'rubykaigi/2025',
        hash_including('search[source]' => sponsorship.tito_source_code),
      )
    end

    it 'raises until the source exists on Tito' do
      expect { described_class.list_for_sponsorship(sponsorship) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'raises when the conference has no tito_slug' do
      conference.update!(tito_slug: nil)
      TitoSource.create!(conference:, sponsorship:, tito_source_id: '1')

      expect { described_class.list_for_sponsorship(sponsorship) }.to raise_error(Must::Violation)
    end
  end

  describe '.list_for_source_id' do
    let(:api) { instance_double(TitoApi, list_registrations: {registrations: [], meta: {total_pages: 1}}) }

    before do
      allow(TitoApi).to receive(:new).and_return(api)
    end

    it "requests Tito's maximum page size" do
      described_class.list_for_source_id('rubykaigi/2025', 'ss_1')

      expect(api).to have_received(:list_registrations).with('rubykaigi/2025', hash_including('page[size]' => '1000'))
    end
  end
end
