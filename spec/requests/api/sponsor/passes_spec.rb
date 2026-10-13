# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SponsorService passes', type: :request do
  let(:conference) do
    FactoryBot.create(:conference, :full, tito_slug: 'ruby-no-kai/rubykaigi2048', ticket_distribution_starts_at: 1.day.ago)
  end
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first) }
  let(:tito_api) { instance_double(TitoApi) }

  before do
    FactoryBot.create(:tito_discount_code, sponsorship:, kind: :attendee, code: 'SA1', quantity: 3)
    FactoryBot.create(:tito_cached_release, conference:, tito_release_id: '11', tito_release_slug: 'sponsor')
    allow(TitoApi).to receive(:new).and_return(tito_api)
  end

  # A ticket as Tito lists it, with Symbol keys.
  def tito_ticket(id: 201, discount_code_used: 'SA1', **overrides)
    {
      id:,
      reference: "T#{id}",
      discount_code_used:,
      release_id: 11,
      email: "ticket#{id}@example.invalid",
      state: 'complete',
      void: false,
      assigned: true,
    }.merge(overrides)
  end

  # A registration as Tito lists it, with Symbol keys.
  def tito_registration(id: 101, tickets: [tito_ticket], **overrides)
    {
      id:,
      slug: "reg-#{id}",
      reference: "R#{id}",
      source: sponsorship.tito_source_code,
      discount_code: 'SA1',
      email: "registrant#{id}@example.invalid",
      state: 'complete',
      free: true,
      paid: false,
      cancelled: false,
      refunded: false,
      partially_refunded: false,
      tickets:,
    }.merge(overrides)
  end

  describe 'ListPassRedemptions' do
    let(:rpc) { connect_method('SponsorService', 'ListPassRedemptions') }

    def request_for(slug = conference.slug) = Rk::SponsorApp::SponsorServiceListPassRedemptionsRequest.new(conference_slug: slug)

    def list_registrations(*registrations, total_pages: 1)
      allow(tito_api).to receive(:list_registrations).and_return(registrations:, meta: {total_pages:})
    end

    it 'answers unauthenticated without a sponsor session' do
      expect(connect_call(rpc, request_for)).to have_attributes(code: 'unauthenticated')
    end

    context 'with a sponsor session' do
      before do
        TitoSource.create!(conference:, sponsorship:, tito_source_id: 'src_1')
        sign_in_sponsor(sponsorship.contact.email)
      end

      it 'lists the discount codes, then the registrations made with them' do
        FactoryBot.create(:tito_discount_code, sponsorship:, kind: :booth_paid, code: 'SP1', quantity: 6)
        FactoryBot.create(:tito_discount_code, sponsorship:, kind: :booth_staff, code: 'SB1', quantity: 2)
        list_registrations(tito_registration(tickets: [tito_ticket, tito_ticket(id: 202, release_id: 99, email: nil, state: 'unassigned', void: true)]))

        result = connect_call(rpc, request_for)

        expect(tito_api).to have_received(:list_registrations).with(
          'ruby-no-kai/rubykaigi2048',
          hash_including('search[source]' => sponsorship.tito_source_code, 'expand' => 'tickets'),
        )
        expect(result.conference).to have_attributes(slug: conference.slug, contact_email_address: conference.contact_email_address)
        expect(result.retraction_enabled).to be(true)
        expect(result.discount_codes.map { [it.kind, it.url, it.has_quantity? ? it.quantity : nil] }).to eq([
          [:KIND_ATTENDEE, 'https://ti.to/ruby-no-kai/rubykaigi2048/discount/SA1', 3],
          [:KIND_BOOTH_STAFF, 'https://ti.to/ruby-no-kai/rubykaigi2048/discount/SB1', 2],
          [:KIND_BOOTH_PAID, 'https://ti.to/ruby-no-kai/rubykaigi2048/discount/SP1', nil],
        ])
        expect(result.registrations.sole).to have_attributes(id: '101', reference: 'R101', email: 'registrant101@example.invalid')
        expect(result.registrations.sole.tickets.map(&:to_h)).to eq([
          {reference: 'T201', release_slug: 'sponsor', email: 'ticket201@example.invalid', state: 'complete'},
          {reference: 'T202', state: 'unassigned', void: true},
        ])
      end

      it "leaves out registrations and tickets claimed with other sponsorships' codes" do
        list_registrations(
          tito_registration(id: 101, tickets: [tito_ticket(id: 201), tito_ticket(id: 202, discount_code_used: 'OTHER')]),
          tito_registration(id: 102, discount_code: 'OTHER', tickets: [tito_ticket(id: 203, discount_code_used: 'OTHER')]),
        )

        registrations = connect_call(rpc, request_for).registrations

        expect(registrations.map(&:id)).to eq(['101'])
        expect(registrations.sole.tickets.map(&:reference)).to eq(['T201'])
        expect(response.body).not_to include('ticket202@example.invalid', 'registrant102@example.invalid')
      end

      it 'offers voiding only for a registration the retraction itself would accept' do
        list_registrations(
          tito_registration(id: 101),
          tito_registration(id: 102, tickets: [tito_ticket(id: 202), tito_ticket(id: 203, discount_code_used: 'OTHER')]),
          tito_registration(id: 103, paid: true, free: false),
        )

        expect(connect_call(rpc, request_for).registrations.map { [it.id, it.retractable] }).to eq([
          ['101', true],
          ['102', false],
          ['103', false],
        ])
      end

      it 'answers a GET and a binary call alike' do
        list_registrations(tito_registration)
        expected = connect_call(rpc, request_for)

        expect(connect_call(rpc, request_for, via: :get)).to eq(expected)
        expect(connect_call(rpc, request_for, codec: :proto)).to eq(expected)
      end

      it 'answers failed_precondition before tickets are distributed' do
        conference.update!(ticket_distribution_starts_at: 1.day.from_now)

        expect(problem_type_of(connect_call(rpc, request_for))).to eq('failed-precondition')
      end

      it 'answers failed_precondition for a conference without a Tito event' do
        conference.update!(tito_slug: nil)

        expect(problem_type_of(connect_call(rpc, request_for))).to eq('failed-precondition')
      end

      it 'answers failed_precondition until the sponsorship has its Tito source' do
        TitoSource.where(sponsorship:).delete_all

        expect(problem_type_of(connect_call(rpc, request_for))).to eq('failed-precondition')
        expect(TitoApi).not_to have_received(:new)
      end

      it 'answers internal when Tito has more registrations than one page', :escaping_exceptions do
        list_registrations(tito_registration, total_pages: 2)

        expect(connect_call(rpc, request_for)).to have_attributes(code: 'internal', message: 'Internal Server Error')
      end
    end
  end
end
