# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AdminService plans', type: :request do
  let(:staff) { FactoryBot.create(:staff) }
  let(:restricted_staff) { FactoryBot.create(:staff, restricted_repos: ['ruby-no-kai/rubykaigi-admitted']) }
  let(:conference) { FactoryBot.create(:conference) }
  let(:closes_at) { Time.zone.parse('2026-03-01 12:00:00') }

  let!(:platinum) do
    FactoryBot.create(:plan, conference:, name: 'Platinum', rank: 2, summary: 'The top tier', price_text: '3,000,000 JPY',
      price: '3000000', price_booth: '500000.5', capacity: 3, number_of_guests: 4, booth_size: 6, words_limit: 200,
      auto_acceptance: false, talkable: true, closes_at:)
  end
  let!(:gold) do
    FactoryBot.create(:plan, conference:, name: 'Gold', rank: 1, summary: nil, price_text: '1,000,000 JPY', price: '1000000',
      price_booth: '0', capacity: 1, number_of_guests: 2, booth_size: nil, words_limit: 100, auto_acceptance: true,
      talkable: nil, closes_at: nil)
  end

  before do
    FactoryBot.create(:sponsorship, conference:, plan: platinum, accepted_at: Time.zone.now)
    FactoryBot.create(:sponsorship, conference:, plan: platinum)
    FactoryBot.create(:sponsorship, conference:, plan: gold, accepted_at: Time.zone.now)
  end

  def expected_platinum
    Rk::SponsorApp::AdminPlan.new(
      id: platinum.id,
      name: 'Platinum',
      rank: 2,
      summary: 'The top tier',
      price_text: '3,000,000 JPY',
      price: '3000000.0',
      price_booth: '500000.5',
      capacity: 3,
      number_of_guests: 4,
      booth_size: 6,
      words_limit: 200,
      auto_acceptance: false,
      talkable: true,
      closes_at: Google::Protobuf::Timestamp.from_time(closes_at),
      active_sponsorship_count: 1,
      sold_out: false,
      closed: true,
      available: false,
    )
  end

  def input(**fields)
    Rk::SponsorApp::PlanInput.new(
      name: 'Silver',
      rank: 3,
      summary: 'For smaller companies',
      price_text: '500,000 JPY',
      price: '500000',
      price_booth: '250000.25',
      capacity: 10,
      number_of_guests: 1,
      booth_size: 2,
      words_limit: 50,
      auto_acceptance: true,
      talkable: true,
      closes_at: Google::Protobuf::Timestamp.from_time(Time.zone.parse('2026-04-01 09:30:00')),
      **fields,
    )
  end

  describe 'ListPlans' do
    let(:rpc) { connect_method('AdminService', 'ListPlans') }

    def request_for(slug = conference.slug) = Rk::SponsorApp::AdminServiceListPlansRequest.new(conference_slug: slug)

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it "lists the conference's plans lowest rank first, with their counts and flags" do
        FactoryBot.create(:plan, name: 'Elsewhere')

        plans = connect_call(rpc, request_for).plans

        expect(plans.map(&:name)).to eq(['Gold', 'Platinum'])
        expect(plans.last).to eq(expected_platinum)
        expect(plans.first).to have_attributes(
          has_summary?: false,
          has_booth_size?: false,
          closes_at: nil,
          talkable: false,
          price_booth: '0.0',
          active_sponsorship_count: 1,
          sold_out: true,
          closed: false,
          available: false,
        )
      end

      it 'answers GET, in JSON and binary, and binary POST alike' do
        expected = connect_call(rpc, request_for)

        expect(connect_call(rpc, request_for, via: :get)).to eq(expected)
        expect(connect_call(rpc, request_for, via: :get, codec: :proto)).to eq(expected)
        expect(connect_call(rpc, request_for, codec: :proto)).to eq(expected)
      end

      it 'returns no plans for a conference without any' do
        expect(connect_call(rpc, request_for(FactoryBot.create(:conference).slug)).plans).to be_empty
      end

      it 'counts sponsorships in as many queries however many plans there are' do
        baseline = query_count { connect_call(rpc, request_for) }
        FactoryBot.create_list(:plan, 3, conference:)

        expect(query_count { connect_call(rpc, request_for) }).to eq(baseline)
      end

      it 'answers not_found for an unknown conference' do
        expect(connect_call(rpc, request_for('nothing'))).to have_attributes(status: 404, code: 'not_found')
      end

      it 'answers invalid_argument for a slug no conference can have' do
        expect(violations_of(connect_call(rpc, request_for('Not A Slug')))).to eq([['conferenceSlug', 'STRING_PATTERN']])
      end
    end

    it 'answers unauthenticated without a staff session, before judging the request' do
      expect(connect_call(rpc, request_for('Not A Slug'))).to have_attributes(status: 401, code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_for)).to have_attributes(status: 403, code: 'permission_denied')
    end
  end

  describe 'GetPlan' do
    let(:rpc) { connect_method('AdminService', 'GetPlan') }

    def request_for(plan_id, slug: conference.slug)
      Rk::SponsorApp::AdminServiceGetPlanRequest.new(conference_slug: slug, plan_id:)
    end

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'returns every setting of the plan' do
        expect(connect_call(rpc, request_for(platinum.id)).plan).to eq(expected_platinum)
      end

      it 'answers GET, in JSON and binary, and binary POST alike' do
        expected = connect_call(rpc, request_for(platinum.id))

        expect(connect_call(rpc, request_for(platinum.id), via: :get)).to eq(expected)
        expect(connect_call(rpc, request_for(platinum.id), via: :get, codec: :proto)).to eq(expected)
        expect(connect_call(rpc, request_for(platinum.id), codec: :proto)).to eq(expected)
      end

      it 'answers not_found for a plan of another conference' do
        other_plan = FactoryBot.create(:plan)

        error = connect_call(rpc, request_for(other_plan.id))

        expect(error).to have_attributes(status: 404, code: 'not_found')
        expect(error.detail(Protobufable::ProblemDetails).type).to eq('https://sponsorships.rubykaigi.org/problems/not-found')
      end

      it "answers not_found when the slug names a conference other than the plan's" do
        other_plan = FactoryBot.create(:plan)

        expect(connect_call(rpc, request_for(platinum.id, slug: other_plan.conference.slug))).to have_attributes(code: 'not_found')
      end

      it 'answers invalid_argument for a plan ID that cannot exist' do
        expect(violations_of(connect_call(rpc, request_for(0)))).to eq([['planId', 'INT64_GT']])
      end
    end

    it 'answers unauthenticated without a staff session, before judging the request' do
      expect(connect_call(rpc, request_for(0))).to have_attributes(code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_for(platinum.id))).to have_attributes(code: 'permission_denied')
    end
  end

  describe 'CreatePlan' do
    let(:rpc) { connect_method('AdminService', 'CreatePlan') }

    def request_with(input, slug: conference.slug)
      Rk::SponsorApp::AdminServiceCreatePlanRequest.new(conference_slug: slug, input:)
    end

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'creates the plan in the conference, storing every field' do
        plan = connect_call(rpc, request_with(input)).plan

        stored = conference.plans.find(plan.id)
        expect(stored).to have_attributes(
          name: 'Silver',
          rank: 3,
          summary: 'For smaller companies',
          price_text: '500,000 JPY',
          price: BigDecimal('500000'),
          price_booth: BigDecimal('250000.25'),
          capacity: 10,
          number_of_guests: 1,
          booth_size: 2,
          words_limit: 50,
          auto_acceptance: true,
          talkable: true,
          closes_at: Time.zone.parse('2026-04-01 09:30:00'),
        )
        expect(plan).to have_attributes(price: '500000.0', price_booth: '250000.25', active_sponsorship_count: 0, sold_out: false)
      end

      it 'returns what GetPlan returns afterwards' do
        created = connect_call(rpc, request_with(input)).plan
        get_request = Rk::SponsorApp::AdminServiceGetPlanRequest.new(conference_slug: conference.slug, plan_id: created.id)

        expect(connect_call(connect_method('AdminService', 'GetPlan'), get_request).plan).to eq(created)
      end

      it 'stores unset optional fields as null' do
        plan = connect_call(rpc, request_with(input(summary: nil, booth_size: nil, closes_at: nil, talkable: false))).plan

        expect(conference.plans.find(plan.id)).to have_attributes(summary: nil, booth_size: nil, closes_at: nil, talkable: false)
        expect(plan).to have_attributes(has_summary?: false, has_booth_size?: false, closes_at: nil, talkable: false)
      end

      it 'creates over binary protobuf too' do
        expect(connect_call(rpc, request_with(input), codec: :proto).plan.name).to eq('Silver')
      end

      it 'answers invalid_argument with a violation per broken rule, creating nothing' do
        error = connect_call(rpc, request_with(input(
          name: ' ',
          summary: '',
          price_text: '',
          price: '1,000',
          price_booth: '-1',
          capacity: -1,
          number_of_guests: -1,
          booth_size: -1,
          words_limit: 0,
        )))

        expect(error).to have_attributes(status: 400, code: 'invalid_argument')
        expect(violations_of(error)).to contain_exactly(
          ['input.name', 'PLAN_INPUT_NAME_NOT_BLANK'],
          ['input.summary', 'PLAN_INPUT_SUMMARY_NOT_BLANK'],
          ['input.priceText', 'REQUIRED'],
          ['input.price', 'PLAN_INPUT_PRICE_FORMAT'],
          ['input.priceBooth', 'PLAN_INPUT_PRICE_BOOTH_FORMAT'],
          ['input.capacity', 'INT32_GTE'],
          ['input.numberOfGuests', 'INT32_GTE'],
          ['input.boothSize', 'INT32_GTE'],
          ['input.wordsLimit', 'INT32_GT'],
        )
        expect(conference.plans.count).to eq(2)
      end

      it 'answers invalid_argument for a blank summary, which reads back as none' do
        expect(violations_of(connect_call(rpc, request_with(input(summary: ' ')))))
          .to eq([['input.summary', 'PLAN_INPUT_SUMMARY_NOT_BLANK']])
      end

      it 'answers invalid_argument for a closing time ProtoJSON cannot spell, creating nothing' do
        error = connect_call(rpc, request_with(input(closes_at: Google::Protobuf::Timestamp.new(seconds: 10**15))), codec: :proto)

        expect(violations_of(error)).to eq([['input.closes_at', 'TIMESTAMP_GTE_LTE']])
        expect(conference.plans.count).to eq(2)
      end

      it 'answers invalid_argument for a price with more digits than the column holds' do
        expect(violations_of(connect_call(rpc, request_with(input(price: '12345678901')))))
          .to eq([['input.price', 'PLAN_INPUT_PRICE_FORMAT']])
      end

      it 'answers invalid_argument for an empty fee in words, and for each whole number left out' do
        error = connect_call(rpc, request_with(input(price: '', rank: nil, capacity: nil, number_of_guests: nil, words_limit: nil)))

        expect(bad_request_of(error).field_violations.map { [it.field, it.reason, it.description] }).to contain_exactly(
          ['input.price', 'PLAN_INPUT_PRICE_FORMAT', 'must be an amount such as 1000 or 1000.50'],
          ['input.rank', 'REQUIRED', 'value is required'],
          ['input.capacity', 'REQUIRED', 'value is required'],
          ['input.numberOfGuests', 'REQUIRED', 'value is required'],
          ['input.wordsLimit', 'REQUIRED', 'value is required'],
        )
      end

      it 'names the field as a binary request spells it' do
        error = connect_call(rpc, request_with(input(price_text: ' ')), codec: :proto)

        expect(violations_of(error)).to eq([['input.price_text', 'PLAN_INPUT_PRICE_TEXT_NOT_BLANK']])
      end

      it 'answers invalid_argument without an input' do
        expect(violations_of(connect_call(rpc, request_with(nil)))).to eq([['input', 'REQUIRED']])
      end

      it 'refuses GET, as creating has side effects' do
        get "#{rpc.path}?#{URI.encode_www_form(connect: 'v1', encoding: 'json', message: request_with(input).to_json)}"

        expect(response).to have_http_status(:method_not_allowed)
      end
    end

    it 'answers unauthenticated before judging the request' do
      expect(connect_call(rpc, request_with(input(name: '')))).to have_attributes(code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_with(input))).to have_attributes(code: 'permission_denied')
      expect(conference.plans.count).to eq(2)
    end
  end

  describe 'UpdatePlan' do
    let(:rpc) { connect_method('AdminService', 'UpdatePlan') }

    def request_with(input, plan_id: gold.id, slug: conference.slug)
      Rk::SponsorApp::AdminServiceUpdatePlanRequest.new(conference_slug: slug, plan_id:, input:)
    end

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'replaces every field' do
        plan = connect_call(rpc, request_with(input)).plan

        expect(gold.reload).to have_attributes(
          name: 'Silver',
          rank: 3,
          summary: 'For smaller companies',
          price_booth: BigDecimal('250000.25'),
          capacity: 10,
          booth_size: 2,
          talkable: true,
          closes_at: Time.zone.parse('2026-04-01 09:30:00'),
        )
        expect(plan).to have_attributes(id: gold.id, name: 'Silver', active_sponsorship_count: 1, sold_out: false)
      end

      it 'updates over binary protobuf too' do
        expect(connect_call(rpc, request_with(input), codec: :proto).plan.name).to eq('Silver')
      end

      it 'round-trips talkable both ways' do
        expect(connect_call(rpc, request_with(input(talkable: true))).plan.talkable).to be(true)
        expect(gold.reload.talkable).to be(true)

        expect(connect_call(rpc, request_with(input(talkable: false))).plan.talkable).to be(false)
        expect(gold.reload.talkable).to be(false)
      end

      it 'clears optional fields left unset' do
        connect_call(rpc, request_with(input(summary: nil, booth_size: nil, closes_at: nil), plan_id: platinum.id))

        expect(platinum.reload).to have_attributes(summary: nil, booth_size: nil, closes_at: nil)
      end

      it 'returns what GetPlan returns afterwards' do
        updated = connect_call(rpc, request_with(input)).plan
        get_request = Rk::SponsorApp::AdminServiceGetPlanRequest.new(conference_slug: conference.slug, plan_id: gold.id)

        expect(connect_call(connect_method('AdminService', 'GetPlan'), get_request).plan).to eq(updated)
      end

      it 'answers not_found for a plan of another conference, leaving it as it was' do
        other_plan = FactoryBot.create(:plan, name: 'Elsewhere')

        expect(connect_call(rpc, request_with(input, plan_id: other_plan.id))).to have_attributes(code: 'not_found')
        expect(other_plan.reload.name).to eq('Elsewhere')
      end

      it 'leaves the plan as it was on a broken rule' do
        error = connect_call(rpc, request_with(input(name: 'Renamed', words_limit: -5)))

        expect(violations_of(error)).to eq([['input.wordsLimit', 'INT32_GT']])
        expect(gold.reload.name).to eq('Gold')
      end
    end

    it 'answers unauthenticated without a staff session, before judging the request' do
      expect(connect_call(rpc, request_with(input(name: '')))).to have_attributes(code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_with(input))).to have_attributes(code: 'permission_denied')
      expect(gold.reload.name).to eq('Gold')
    end
  end
end
