# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PassRedemption do
  let(:conference) { FactoryBot.create(:conference, tito_slug: 'rubykaigi/2025') }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:) }
  let(:ticket) do
    PassRedemption::Ticket.new(
      id: 1, reference: 'T-1',
      discount_code: 'CODE', release: nil, release_id: '10',
      email: 'ticket@example.invalid',
      state: 'complete',
      void: false, assigned: true,
    )
  end

  let(:registration) do
    PassRedemption::Registration.new(
      id: 2, reference: 'R-1',
      discount_code: 'CODE', source: 'src',
      email: 'reg@example.invalid',
      state: 'complete',
      free: true, paid: false, cancelled: false, refunded: false, partially_refunded: false,
      tickets: [ticket],
    )
  end

  describe 'JSON serialization' do
    it 'serializes with encoder options as render json: passes them' do
      json = JSON.parse({registrations: [registration]}.to_json(status: :ok))

      expect(json.dig('registrations', 0)).to include(
        'reference' => 'R-1',
        'retractable' => true,
        'tickets' => [include('reference' => 'T-1', 'release_id' => '10')],
      )
    end
  end

  describe PassRedemption::Collection do
    describe '.from_tito_registration_list' do
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

      it 'builds registrations from the Tito response' do
        collection = described_class.from_tito_registration_list(
          {registrations: [registration], meta: {total_pages: 1}},
          sponsorship:,
        )

        expect(collection.registrations.size).to eq(1)
        reg = collection.registrations.first
        expect(reg.reference).to eq('ABCD')
        expect(reg.retractable?).to be true
        expect(reg.tickets.first.release).to eq(release)
        expect(reg.tickets.first.discount_code).to eq(discount_code.code)
      end

      it 'drops registrations made with another discount code' do
        collection = described_class.from_tito_registration_list(
          {registrations: [registration.merge(discount_code: 'OTHER')], meta: {total_pages: 1}},
          sponsorship:,
        )

        expect(collection.registrations).to be_empty
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
end
