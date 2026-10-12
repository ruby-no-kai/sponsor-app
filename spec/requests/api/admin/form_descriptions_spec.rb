# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AdminService form descriptions', type: :request do
  let(:staff) { FactoryBot.create(:staff) }
  let(:restricted_staff) { FactoryBot.create(:staff, restricted_repos: ['ruby-no-kai/rubykaigi-admitted']) }
  let(:conference) { FactoryBot.create(:conference) }

  before do
    FactoryBot.create(:plan, conference:, name: 'Platinum')
    FactoryBot.create(:plan, conference:, name: 'Gold')
  end

  def option(value:, name: value.capitalize, conditions: [], priority_human: [])
    Rk::SponsorApp::FallbackOption.new(value:, name:, conditions:, priority_human:)
  end

  def condition(**)
    Rk::SponsorApp::FallbackOption::Condition.new(**)
  end

  def input(**fields)
    Rk::SponsorApp::FormDescriptionInput.new(
      locale: 'en',
      head: '# Welcome',
      plan_help: 'Pick a *plan*.',
      booth_help: 'Booths',
      policy_help: 'Policies',
      ticket_help: 'Tickets',
      sponsor_event_help: 'Events',
      event_policy: 'Event policy',
      fallback_options: [
        option(value: 'gold', name: 'Change to Gold', conditions: [condition(plans: ['Platinum'], booth_request: false)],
          priority_human: ['Gold', '!withdraw']),
        option(value: 'withdraw', conditions: [condition(booth_request: true)]),
      ],
      **fields,
    )
  end

  describe 'GetFormDescription' do
    let(:rpc) { connect_method('AdminService', 'GetFormDescription') }

    let!(:form_description) do
      FactoryBot.create(:form_description, conference:, locale: 'en', head: '# Welcome', ticket_help: nil,
        fallback_options: Rk::SponsorApp::Internal::FallbackOptions.new(options: [
          Rk::SponsorApp::Internal::FallbackOption.new(
            value: 'gold',
            name: 'Change to Gold',
            conditions: [Rk::SponsorApp::Internal::FallbackOption::Condition.new(plans: ['Platinum'], booth_request: false)],
            priority_human: ['Gold'],
          ),
        ]))
    end

    def request_for(locale, slug: conference.slug)
      Rk::SponsorApp::AdminServiceGetFormDescriptionRequest.new(conference_slug: slug, locale:)
    end

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'returns the texts, their rendering and the fallback options over POST JSON' do
        form = connect_call(rpc, request_for('en')).form_description

        expect(form).to have_attributes(locale: 'en', head: '# Welcome', ticket_help: '', head_html: form_description.head_html)
        expect(form.head_html).to include('<h1')
        expect(form.fallback_options).to eq([
          option(value: 'gold', name: 'Change to Gold', conditions: [condition(plans: ['Platinum'], booth_request: false)],
            priority_human: ['Gold']),
        ])
      end

      it 'keeps an absent booth request absent' do
        form_description.update!(fallback_options: Rk::SponsorApp::Internal::FallbackOptions.new(options: [
          Rk::SponsorApp::Internal::FallbackOption.new(
            value: 'gold', name: 'Gold', conditions: [Rk::SponsorApp::Internal::FallbackOption::Condition.new(plans: ['Platinum'])],
          ),
        ]))

        expect(connect_call(rpc, request_for('en')).form_description.fallback_options.first.conditions.first)
          .to have_attributes(has_booth_request?: false)
      end

      it 'answers GET, in JSON and binary, and binary POST alike' do
        expected = connect_call(rpc, request_for('en'))

        expect(connect_call(rpc, request_for('en'), via: :get)).to eq(expected)
        expect(connect_call(rpc, request_for('en'), via: :get, codec: :proto)).to eq(expected)
        expect(connect_call(rpc, request_for('en'), codec: :proto)).to eq(expected)
      end

      it 'answers not_found for a locale the conference is not described in' do
        error = connect_call(rpc, request_for('ja'))

        expect(error).to have_attributes(status: 404, code: 'not_found')
        expect(error.detail(Protobufable::ProblemDetails).type).to eq('https://sponsorships.rubykaigi.org/problems/not-found')
      end
    end

    it 'answers unauthenticated without a staff session' do
      expect(connect_call(rpc, request_for('en'))).to have_attributes(status: 401, code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_for('en'))).to have_attributes(status: 403, code: 'permission_denied')
    end
  end

  describe 'CreateFormDescription' do
    let(:rpc) { connect_method('AdminService', 'CreateFormDescription') }

    def request_with(input, slug: conference.slug)
      Rk::SponsorApp::AdminServiceCreateFormDescriptionRequest.new(conference_slug: slug, input:)
    end

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'creates the form description, rendering its texts and storing its fallback options' do
        form = connect_call(rpc, request_with(input)).form_description

        expect(form).to have_attributes(locale: 'en', head: '# Welcome', plan_help: 'Pick a *plan*.')
        expect(form.head_html).to include('<h1')
        expect(form.plan_help_html).to include('<em>plan</em>')
        expect(form.fallback_options).to eq(input.fallback_options)

        stored = conference.form_descriptions.find_by!(locale: 'en')
        expect(stored.fallback_options).to eq(Rk::SponsorApp::Internal::FallbackOptions.new(options: [
          Rk::SponsorApp::Internal::FallbackOption.new(
            value: 'gold',
            name: 'Change to Gold',
            conditions: [Rk::SponsorApp::Internal::FallbackOption::Condition.new(plans: ['Platinum'], booth_request: false)],
            priority_human: ['Gold', '!withdraw'],
          ),
          Rk::SponsorApp::Internal::FallbackOption.new(
            value: 'withdraw',
            name: 'Withdraw',
            conditions: [Rk::SponsorApp::Internal::FallbackOption::Condition.new(booth_request: true)],
          ),
        ]))
      end

      it 'creates over binary protobuf too' do
        expect(connect_call(rpc, request_with(input(locale: 'ja')), codec: :proto).form_description.locale).to eq('ja')
      end

      it 'answers invalid_argument naming an option without a value' do
        error = connect_call(rpc, request_with(input(fallback_options: [option(value: 'gold'), option(value: '', name: 'Nameless')])))

        expect(error).to have_attributes(status: 400, code: 'invalid_argument')
        expect(violations_of(error)).to eq([['input.fallbackOptions[1].value', 'REQUIRED']])
        expect(conference.form_descriptions).to be_empty
      end

      it 'names the field as a binary request spells it' do
        error = connect_call(rpc, request_with(input(fallback_options: [option(value: '', name: 'Nameless')])), codec: :proto)

        expect(violations_of(error)).to eq([['input.fallback_options[0].value', 'REQUIRED']])
      end

      it 'answers invalid_argument for options sharing a value and conditions' do
        error = connect_call(rpc, request_with(input(fallback_options: [option(value: 'gold'), option(value: 'gold', name: 'Gold again')])))

        expect(violations_of(error)).to eq([['input.fallbackOptions', 'FALLBACK_OPTIONS_DISTINCT']])
      end

      it 'answers invalid_argument for options too many to check for repeats' do
        options = Array.new(100) { |i| option(value: "option#{i}") }
        error = connect_call(rpc, request_with(input(fallback_options: options)))

        expect(error).to have_attributes(status: 400, code: 'invalid_argument')
        expect(violations_of(error)).to eq([['input.fallbackOptions', 'REPEATED_MAX_ITEMS']])
      end

      it 'answers invalid_argument for a locale the app is not available in' do
        expect(violations_of(connect_call(rpc, request_with(input(locale: 'fr'))))).to eq([['input.locale', 'STRING_IN']])
      end

      it 'answers invalid_argument for an empty locale as a missing one' do
        expect(violations_of(connect_call(rpc, request_with(input(locale: ''))))).to eq([['input.locale', 'REQUIRED']])
      end

      it 'answers invalid_argument without an input' do
        expect(violations_of(connect_call(rpc, request_with(nil)))).to eq([['input', 'REQUIRED']])
      end

      it 'answers the invalid-record problem for a condition naming a plan the conference lacks' do
        error = connect_call(rpc, request_with(input(fallback_options: [
          option(value: 'gold', conditions: [condition(plans: ['Diamond'])]),
        ])))

        expect(error).to have_attributes(status: 400, code: 'invalid_argument')
        expect(error.detail(Protobufable::ProblemDetails)).to have_attributes(
          type: 'https://sponsorships.rubykaigi.org/problems/invalid-record',
          status: 422,
        )
        expect(bad_request_of(error).field_violations.map { [it.field, it.reason, it.description] }).to eq([
          ['input.fallbackOptions', 'UNKNOWN_PLAN', 'option 1, condition 1 names Diamond, which is not a plan of the conference'],
        ])
        expect(conference.form_descriptions).to be_empty
      end

      it 'answers aborted with the conflict problem for a locale already described' do
        FactoryBot.create(:form_description, conference:, locale: 'en')

        error = connect_call(rpc, request_with(input))

        expect(error).to have_attributes(status: 409, code: 'aborted')
        expect(error.detail(Protobufable::ProblemDetails).type).to eq('https://sponsorships.rubykaigi.org/problems/conflict')
      end

      it 'refuses GET, as creating has side effects' do
        get "#{rpc.path}?#{URI.encode_www_form(connect: 'v1', encoding: 'json', message: request_with(input).to_json)}"

        expect(response).to have_http_status(:method_not_allowed)
      end
    end

    it 'answers unauthenticated before judging the request' do
      expect(connect_call(rpc, request_with(input(locale: 'fr')))).to have_attributes(code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_with(input))).to have_attributes(code: 'permission_denied')
      expect(conference.form_descriptions).to be_empty
    end
  end

  describe 'UpdateFormDescription' do
    let(:rpc) { connect_method('AdminService', 'UpdateFormDescription') }
    let!(:form_description) { FactoryBot.create(:form_description, conference:, locale: 'en', head: '# Before') }

    def request_with(input, locale: 'en')
      Rk::SponsorApp::AdminServiceUpdateFormDescriptionRequest.new(conference_slug: conference.slug, locale:, input:)
    end

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'replaces every field and renders the texts again' do
        form = connect_call(rpc, request_with(input(head: '# After'))).form_description

        expect(form.head_html).to include('After')
        expect(form_description.reload).to have_attributes(head: '# After', event_policy: 'Event policy')
        expect(form_description.head_html).to include('After')
        expect(form_description.fallback_options.options.map(&:value)).to eq(%w[gold withdraw])
      end

      it 'returns what GetFormDescription returns afterwards' do
        updated = connect_call(rpc, request_with(input)).form_description
        get_request = Rk::SponsorApp::AdminServiceGetFormDescriptionRequest.new(conference_slug: conference.slug, locale: 'en')

        expect(connect_call(connect_method('AdminService', 'GetFormDescription'), get_request).form_description).to eq(updated)
      end

      it 'moves the form description to another locale' do
        connect_call(rpc, request_with(input(locale: 'ja')))

        expect(form_description.reload.locale).to eq('ja')
      end

      it 'answers aborted when moving onto a locale already described' do
        FactoryBot.create(:form_description, conference:, locale: 'ja')

        expect(connect_call(rpc, request_with(input(locale: 'ja')))).to have_attributes(code: 'aborted')
        expect(form_description.reload.locale).to eq('en')
      end

      it 'answers not_found for a locale the conference is not described in' do
        expect(connect_call(rpc, request_with(input, locale: 'ja'))).to have_attributes(code: 'not_found')
      end

      it 'leaves the record as it was on a broken rule' do
        error = connect_call(rpc, request_with(input(head: '# After', fallback_options: [option(value: ' ', name: 'Blank')])))

        expect(violations_of(error)).to eq([['input.fallbackOptions[0].value', 'FALLBACK_OPTION_VALUE_NOT_BLANK']])
        expect(form_description.reload.head).to eq('# Before')
      end
    end

    it 'answers unauthenticated without a staff session' do
      expect(connect_call(rpc, request_with(input))).to have_attributes(code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_with(input(head: '# After')))).to have_attributes(code: 'permission_denied')
      expect(form_description.reload.head).to eq('# Before')
    end
  end
end
