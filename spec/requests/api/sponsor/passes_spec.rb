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

  def http_error(status) = HTTPX::HTTPError.new(instance_double(HTTPX::Response, status:, headers: {}, body: ''))

  # FactoryBot takes tito_registration for an alias of tito_registration_id, so this skips the factory.
  def save_retraction(sponsorship: self.sponsorship, registration: tito_registration, reason: 'Mistyped address', completed: false)
    TitoTicketRetraction.create!(
      sponsorship:,
      conference:,
      tito_registration_id: registration.fetch(:id).to_s,
      tito_registration: registration.deep_stringify_keys,
      reason:,
      completed:,
    )
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

  describe 'GetPassRetraction' do
    let(:rpc) { connect_method('SponsorService', 'GetPassRetraction') }

    def request_for(registration_id = '101', slug: conference.slug)
      Rk::SponsorApp::SponsorServiceGetPassRetractionRequest.new(conference_slug: slug, tito_registration_id: registration_id)
    end

    def get_registration(registration)
      allow(tito_api).to receive(:get_registration).and_return(registration:)
    end

    it 'answers unauthenticated without a sponsor session' do
      expect(connect_call(rpc, request_for)).to have_attributes(code: 'unauthenticated')
    end

    it 'answers unauthenticated before judging the request' do
      expect(connect_call(rpc, request_for('reg-101'))).to have_attributes(code: 'unauthenticated')
    end

    context 'with a sponsor session' do
      before { sign_in_sponsor(sponsorship.contact.email) }

      it 'prepares a retraction from the registration as Tito holds it now' do
        get_registration(tito_registration(tickets: [tito_ticket, tito_ticket(id: 202, release_id: 99, email: nil)]))

        result = connect_call(rpc, request_for)

        expect(tito_api).to have_received(:get_registration).with('ruby-no-kai/rubykaigi2048', '101', 'expand' => 'tickets')
        expect(result).to have_attributes(retraction_enabled: true)
        expect(result.conference).to have_attributes(slug: conference.slug, name: conference.name)
        expect(result.retraction).to have_attributes(
          tito_registration_id: '101',
          state: :STATE_NOT_REQUESTED,
          reference: 'R101',
          email: 'registrant101@example.invalid',
          retractable: false,
          has_reason?: false,
        )
        expect(result.retraction.tickets.map(&:to_h)).to eq([
          {reference: 'T201', release_slug: 'sponsor', email: 'ticket201@example.invalid'},
          {reference: 'T202'},
        ])
        expect(TitoTicketRetraction.count).to eq(0)
      end

      it 'tells whether the registration qualifies for voiding' do
        get_registration(tito_registration)

        expect(connect_call(rpc, request_for).retraction.retractable).to be(true)
      end

      it 'answers a GET and a binary call alike' do
        get_registration(tito_registration)
        expected = connect_call(rpc, request_for)

        expect(connect_call(rpc, request_for, via: :get)).to eq(expected)
        expect(connect_call(rpc, request_for, via: :get, codec: :proto)).to eq(expected)
        expect(connect_call(rpc, request_for, codec: :proto)).to eq(expected)
      end

      it 'answers not_found, giving away nothing, for a registration under another source' do
        get_registration(tito_registration(source: 'ss_0'))

        expect(connect_call(rpc, request_for)).to have_attributes(code: 'not_found')
        expect(response.body).not_to include('registrant101', 'ticket201')
      end

      it 'answers not_found for a registration made with another discount code' do
        get_registration(tito_registration(discount_code: 'OTHER'))

        expect(connect_call(rpc, request_for)).to have_attributes(code: 'not_found')
        expect(response.body).not_to include('registrant101', 'ticket201')
      end

      it 'answers not_found for a registration holding a ticket claimed with another code' do
        get_registration(tito_registration(tickets: [tito_ticket, tito_ticket(id: 202, discount_code_used: 'OTHER')]))

        expect(connect_call(rpc, request_for)).to have_attributes(code: 'not_found')
        expect(response.body).not_to include('registrant101', 'ticket202')
      end

      it 'answers not_found when Tito answers with another registration' do
        get_registration(tito_registration(id: 999))

        expect(connect_call(rpc, request_for)).to have_attributes(code: 'not_found')
      end

      it 'answers not_found for a registration Tito does not have' do
        allow(tito_api).to receive(:get_registration).and_raise(http_error(404))

        expect(connect_call(rpc, request_for)).to have_attributes(code: 'not_found')
      end

      it 'returns a saved retraction without asking Tito' do
        save_retraction(reason: 'Mistyped address')

        result = connect_call(rpc, request_for)

        expect(TitoApi).not_to have_received(:new)
        expect(result.retraction).to have_attributes(state: :STATE_PENDING, reference: 'R101', reason: 'Mistyped address')
      end

      it 'tells a completed retraction apart' do
        save_retraction(completed: true)

        expect(connect_call(rpc, request_for).retraction.state).to eq(:STATE_COMPLETED)
      end

      it "asks Tito rather than return another sponsorship's retraction of the same ID" do
        other = FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first)
        FactoryBot.create(:tito_discount_code, sponsorship: other, kind: :attendee, code: 'OA1')
        others = tito_registration(source: other.tito_source_code, discount_code: 'OA1', tickets: [tito_ticket(discount_code_used: 'OA1')])
        save_retraction(sponsorship: other, registration: others)
        get_registration(others)

        expect(connect_call(rpc, request_for)).to have_attributes(code: 'not_found')
        expect(tito_api).to have_received(:get_registration)
      end

      it 'answers failed_precondition before tickets are distributed' do
        conference.update!(ticket_distribution_starts_at: nil)

        expect(problem_type_of(connect_call(rpc, request_for))).to eq('failed-precondition')
      end

      it 'answers failed_precondition for a conference without a Tito event' do
        conference.update!(tito_slug: nil)

        expect(problem_type_of(connect_call(rpc, request_for))).to eq('failed-precondition')
      end

      it 'answers invalid_argument for an ID that is not one' do
        expect(violations_of(connect_call(rpc, request_for('reg-101')))).to eq([['titoRegistrationId', 'STRING_PATTERN']])
      end
    end
  end

  describe 'CreatePassRetraction' do
    let(:rpc) { connect_method('SponsorService', 'CreatePassRetraction') }

    def request_for(registration_id = '101', reason: 'Mistyped address', confirmed: true)
      Rk::SponsorApp::SponsorServiceCreatePassRetractionRequest.new(
        conference_slug: conference.slug,
        tito_registration_id: registration_id,
        input: Rk::SponsorApp::PassRetractionInput.new(reason:, confirmed:),
      )
    end

    before do
      allow(Rails.application.config.x).to receive(:public_url_host).and_return('sponsorships.example.invalid')
      allow(tito_api).to receive_messages(get_registration: {registration: tito_registration}, cancel_registration: {cancellation: {}})
      allow(tito_api).to receive(:create_registration_note)
      allow(SlackWebhookJob).to receive(:perform_later)
    end

    it 'answers unauthenticated without a sponsor session' do
      expect(connect_call(rpc, request_for)).to have_attributes(code: 'unauthenticated')
    end

    it 'answers unauthenticated before judging the request' do
      expect(connect_call(rpc, request_for('x', reason: '', confirmed: false))).to have_attributes(code: 'unauthenticated')
      expect(TitoApi).not_to have_received(:new)
    end

    context 'with a sponsor session' do
      before { sign_in_sponsor(sponsorship.contact.email) }

      it 'voids the registration on Tito and answers with the completed retraction' do
        result = connect_call(rpc, request_for)

        expect(tito_api).to have_received(:create_registration_note).with(
          'ruby-no-kai/rubykaigi2048',
          '101',
          content: a_string_including('Mistyped address'),
        )
        expect(tito_api).to have_received(:cancel_registration).with('ruby-no-kai/rubykaigi2048', '101')
        expect(result.retraction).to have_attributes(
          tito_registration_id: '101',
          state: :STATE_COMPLETED,
          reference: 'R101',
          reason: 'Mistyped address',
        )
        expect(TitoTicketRetraction.sole).to have_attributes(sponsorship:, conference:, completed: true, reason: 'Mistyped address')
        expect(SlackWebhookJob).to have_received(:perform_later)
      end

      it 'answers a binary call' do
        expect(connect_call(rpc, request_for, codec: :proto).retraction).to have_attributes(state: :STATE_COMPLETED, reason: 'Mistyped address')
      end

      it 'answers failed_precondition once voiding is disabled, without asking Tito' do
        conference.update!(pass_retraction_disables_at: 1.minute.ago)

        expect(problem_type_of(connect_call(rpc, request_for))).to eq('failed-precondition')
        expect(TitoApi).not_to have_received(:new)
      end

      it 'answers invalid_argument until the sponsor confirms' do
        error = connect_call(rpc, request_for(confirmed: false))

        expect(violations_of(error)).to eq([['input.confirmed', 'BOOL_CONST']])
        expect(TitoApi).not_to have_received(:new)
      end

      it 'answers invalid_argument without a reason' do
        expect(violations_of(connect_call(rpc, request_for(reason: '')))).to eq([['input.reason', 'REQUIRED']])
      end

      it 'answers invalid_argument for a blank reason without asking Tito' do
        expect(violations_of(connect_call(rpc, request_for(reason: '   '), codec: :proto)))
          .to eq([['input.reason', 'PASS_RETRACTION_INPUT_REASON_NOT_BLANK']])
        expect(TitoApi).not_to have_received(:new)
      end

      it 'answers invalid_argument for a registration that does not qualify, as the request as a whole' do
        allow(tito_api).to receive(:get_registration).and_return(registration: tito_registration(paid: true, free: false))

        error = connect_call(rpc, request_for)

        expect(problem_type_of(error)).to eq('invalid-record')
        expect(bad_request_of(error).field_violations.map { [it.field, it.description] })
          .to eq([['', 'Registration cannot be voided automatically']])
        expect(tito_api).not_to have_received(:cancel_registration)
      end

      it 'answers not_found for a registration that did not come through the sponsorship' do
        allow(tito_api).to receive(:get_registration).and_return(registration: tito_registration(source: 'ss_0'))

        expect(connect_call(rpc, request_for)).to have_attributes(code: 'not_found')
        expect(response.body).not_to include('registrant101')
        expect(TitoTicketRetraction.count).to eq(0)
      end

      it 'keeps the retraction when Tito fails, and runs it again when called again', :escaping_exceptions do
        allow(tito_api).to receive(:cancel_registration).and_raise(http_error(503))

        expect(connect_call(rpc, request_for)).to have_attributes(code: 'internal')
        expect(TitoTicketRetraction.sole).to have_attributes(completed: false)

        allow(tito_api).to receive(:cancel_registration).and_return(cancellation: {})

        expect(connect_call(rpc, request_for(reason: 'Mistyped address, twice')).retraction).to have_attributes(
          state: :STATE_COMPLETED,
          reason: 'Mistyped address, twice',
        )
        expect(TitoTicketRetraction.sole).to have_attributes(completed: true)
      end

      it 'answers with a completed retraction as it stands' do
        save_retraction(reason: 'First reason', completed: true)

        expect(connect_call(rpc, request_for).retraction).to have_attributes(state: :STATE_COMPLETED, reason: 'First reason')
        expect(TitoApi).not_to have_received(:new)
      end
    end
  end
end
