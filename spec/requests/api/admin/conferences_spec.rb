# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AdminService conferences', type: :request do
  let(:staff) { FactoryBot.create(:staff) }
  let(:restricted_staff) { FactoryBot.create(:staff, restricted_repos: ['ruby-no-kai/rubykaigi-admitted']) }

  def timestamp(time) = Google::Protobuf::Timestamp.new(seconds: time.to_i)

  def input(**fields)
    Rk::SponsorApp::ConferenceInput.new(
      name: 'RubyKaigi 2027',
      slug: 'rubykaigi2027',
      contact_email_address: 'sponsorships@rubykaigi.example.invalid',
      application_opens_at: timestamp(Time.utc(2027, 1, 15)),
      application_closes_at: timestamp(Time.utc(2027, 3, 1)),
      amendment_closes_at: timestamp(Time.utc(2027, 3, 15)),
      event_submission_starts_at: timestamp(Time.utc(2027, 2, 1)),
      ticket_distribution_starts_at: timestamp(Time.utc(2027, 4, 1)),
      pass_retraction_disables_at: timestamp(Time.utc(2027, 5, 1)),
      no_plan_allowed: false,
      booth_capacity: 30,
      additional_attendees_registration_open: true,
      hidden: false,
      allow_restricted_access: true,
      github_repo: 'ruby-no-kai/rubykaigi.org@master:data/year_2027/sponsors.yml',
      github_repo_images_path: 'images',
      tito_slug: 'rubykaigi/2027',
      tito_booth_paid_flat_discount_amount: '15000.5',
      **fields,
    )
  end

  describe 'ListConferences' do
    let(:rpc) { connect_method('AdminService', 'ListConferences') }
    let(:request_message) { Rk::SponsorApp::AdminServiceListConferencesRequest.new }

    let!(:older) { FactoryBot.create(:conference, application_opens_at: Time.utc(2026, 1, 15)) }
    let!(:newer) { FactoryBot.create(:conference, hidden: true, booth_capacity: 0) }

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'lists every conference, most recently created first, over POST JSON' do
        response_message = connect_call(rpc, request_message)

        expect(response_message.conferences.map { it.conference.slug }).to eq([newer.slug, older.slug])
        expect(response_message.conferences.last.conference).to have_attributes(
          name: older.name,
          contact_email_address: older.contact_email_address,
          application_opens_at: Google::Protobuf::Timestamp.new(seconds: Time.utc(2026, 1, 15).to_i),
          booths_offered: true,
        )
        expect(response_message.conferences.first.conference).to have_attributes(application_opens_at: nil, booths_offered: false)
      end

      it 'marks hidden conferences, whose application form URL carries the invite code' do
        response_message = connect_call(rpc, request_message)

        expect(response_message.conferences.first).to have_attributes(
          hidden: true,
          application_form_url: "http://www.example.com/conferences/#{newer.slug}/sponsorship/new?invite_code=#{newer.invite_code}",
          booth_capacity: 0,
        )
        expect(response_message.conferences.last).to have_attributes(
          hidden: false,
          application_form_url: "http://www.example.com/conferences/#{older.slug}/sponsorship/new",
          booth_capacity: older.booth_capacity,
        )
      end

      it 'answers a GET with the same conferences' do
        expect(connect_call(rpc, request_message, via: :get).conferences.map { it.conference.slug }).to eq([newer.slug, older.slug])
      end

      it 'answers binary protobuf in binary' do
        response_message = connect_call(rpc, request_message, codec: :proto)

        expect(response.media_type).to eq('application/proto')
        expect(response_message.conferences.map { it.conference.slug }).to eq([newer.slug, older.slug])
      end

      it 'answers ProtoJSON in lowerCamelCase, leaving unset fields out' do
        connect_call(rpc, request_message)

        conference = response.parsed_body.fetch('conferences').first
        expect(conference).to include('hidden' => true, 'applicationFormUrl' => be_present)
        expect(conference.fetch('conference')).to include('slug' => newer.slug, 'contactEmailAddress' => newer.contact_email_address)
        expect(conference.fetch('conference')).not_to have_key('applicationOpensAt')
      end
    end

    it 'lists only the conferences a restricted staff member may manage' do
      admitted = FactoryBot.create(:conference, allow_restricted_access: true, github_repo: 'ruby-no-kai/rubykaigi-admitted@main:data')
      FactoryBot.create(:conference, allow_restricted_access: false, github_repo: 'ruby-no-kai/rubykaigi-admitted@main:data')
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_message).conferences.map { it.conference.slug }).to eq([admitted.slug])
    end

    it 'answers unauthenticated without a staff session' do
      error = connect_call(rpc, request_message)

      expect(error).to have_attributes(status: 401, code: 'unauthenticated')
      expect(error.detail(Protobufable::ProblemDetails).type).to eq('https://sponsorships.rubykaigi.org/problems/unauthenticated')
    end
  end

  describe 'GetConference' do
    let(:rpc) { connect_method('AdminService', 'GetConference') }
    let(:conference) do
      FactoryBot.create(:conference, allow_restricted_access: true, github_repo: 'ruby-no-kai/rubykaigi-admitted@main:data')
    end

    def request_for(slug) = Rk::SponsorApp::AdminServiceGetConferenceRequest.new(conference_slug: slug)

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'returns the conference over POST JSON' do
        expect(connect_call(rpc, request_for(conference.slug)).conference).to have_attributes(
          conference: have_attributes(slug: conference.slug, name: conference.name),
          hidden: false,
          allow_restricted_access: true,
          booth_capacity: conference.booth_capacity,
        )
      end

      it 'returns the conference over GET, JSON and binary' do
        expect(connect_call(rpc, request_for(conference.slug), via: :get).conference.conference.slug).to eq(conference.slug)
        expect(connect_call(rpc, request_for(conference.slug), via: :get, codec: :proto).conference.conference.slug).to eq(conference.slug)
      end

      it 'returns the conference over POST binary' do
        expect(connect_call(rpc, request_for(conference.slug), codec: :proto).conference.conference.slug).to eq(conference.slug)
      end

      it 'carries the invite code in the application form URL of a hidden conference' do
        conference.update!(hidden: true)

        expect(connect_call(rpc, request_for(conference.slug)).conference).to have_attributes(
          hidden: true,
          application_form_url: "http://www.example.com/conferences/#{conference.slug}/sponsorship/new?invite_code=#{conference.invite_code}",
        )
      end

      it 'answers not_found with the problem document and the request ID' do
        error = connect_call(rpc, request_for('rubykaigi1999'))

        expect(error).to have_attributes(status: 404, code: 'not_found', message: 'No conference has the slug "rubykaigi1999".')
        expect(error.detail(Protobufable::ProblemDetails)).to have_attributes(
          type: 'https://sponsorships.rubykaigi.org/problems/not-found',
          title: 'Not Found',
          status: 404,
        )
        expect(error.detail(Google::Rpc::RequestInfo).request_id).to eq(response.request.request_id)
        expect(error.detail(Google::Rpc::RequestInfo).request_id).to be_present
      end

      it 'localizes the problem title' do
        cookies['__Host-rk-sponsorapp2-hl'] = 'ja'

        error = connect_call(rpc, request_for('rubykaigi1999'))

        expect(error.detail(Protobufable::ProblemDetails).title).to eq('見つかりません')
      end

      it 'answers invalid_argument naming the field as the JSON request spells it' do
        error = connect_call(rpc, request_for('Not A Slug'))

        expect(error).to have_attributes(status: 400, code: 'invalid_argument')
        violations = error.detail(Google::Rpc::BadRequest).field_violations
        expect(violations.map(&:field)).to all(eq('conferenceSlug'))
        expect(violations.map(&:reason)).to eq(['STRING_PATTERN'])
        expect(error.detail(Google::Rpc::RequestInfo)).to be_present
      end

      it 'names the field as a binary request spells it' do
        error = connect_call(rpc, request_for(''), codec: :proto)

        violations = error.detail(Google::Rpc::BadRequest).field_violations
        expect(violations.map(&:field)).to all(eq('conference_slug'))
        expect(violations.map(&:reason)).to include('STRING_MIN_LEN')
      end
    end

    context 'with plans, sponsorships and form descriptions' do
      let!(:gold) { FactoryBot.create(:plan, conference:, name: 'Gold', rank: 2, capacity: 8) }
      let!(:ruby) { FactoryBot.create(:plan, conference:, name: 'Ruby', rank: 1, capacity: 2) }
      let!(:accepted) { FactoryBot.create(:sponsorship, conference:, plan: ruby, accepted_at: Time.zone.now) }
      let!(:pending) do
        FactoryBot.create(:sponsorship, conference:, plan: gold, customization_name: 'Gold Plus', booth_assigned: true)
      end
      let!(:undetermined) { FactoryBot.create(:sponsorship, conference:, plan: nil, suspended: true) }
      let!(:withdrawn) do
        FactoryBot.create(:sponsorship, conference:, plan: ruby, accepted_at: Time.zone.now, withdrawn_at: Time.zone.now)
      end

      before do
        sign_in_staff(staff)
        FactoryBot.create(:form_description, conference:, locale: 'ja')
        FactoryBot.create(:form_description, conference:, locale: 'en')
        FactoryBot.create(:sponsorship, conference: FactoryBot.create(:conference), plan: nil)
      end

      it 'lists the form description locales in the order they were added' do
        expect(connect_call(rpc, request_for(conference.slug)).form_description_locales).to eq(%w[ja en])
      end

      it 'lists plans by rank, counting only active sponsorships against capacity' do
        plans = connect_call(rpc, request_for(conference.slug)).plans

        expect(plans.map(&:id)).to eq([ruby.id, gold.id])
        expect(plans.first).to have_attributes(name: 'Ruby', rank: 1, capacity: 2, active_sponsorship_count: 1)
        expect(plans.last).to have_attributes(name: 'Gold', rank: 2, capacity: 8, active_sponsorship_count: 0)
      end

      it 'lists plans of the same rank oldest first' do
        silver = FactoryBot.create(:plan, conference:, name: 'Silver', rank: 2)
        gold.update!(updated_at: Time.zone.now) # rewrites gold's row after silver's, so only the ID orders them

        expect(connect_call(rpc, request_for(conference.slug)).plans.map(&:id)).to eq([ruby.id, gold.id, silver.id])
      end

      it 'lists every sponsorship of the conference, oldest first, with the state behind each badge' do
        sponsorships = connect_call(rpc, request_for(conference.slug)).sponsorships

        expect(sponsorships.map(&:id)).to eq([accepted, pending, undetermined, withdrawn].map(&:id))
        expect(sponsorships.map(&:state))
          .to eq(%i[SPONSORSHIP_STATE_ACTIVE SPONSORSHIP_STATE_PENDING SPONSORSHIP_STATE_PENDING SPONSORSHIP_STATE_WITHDRAWN])
        expect(sponsorships[0]).to have_attributes(
          name: accepted.name,
          plan_id: ruby.id,
          has_customization_name?: false,
          booth_assigned: false,
          customization_planned: false,
          suspended: false,
          organization: have_attributes(domain: accepted.organization.domain, name: accepted.organization.name),
        )
        expect(sponsorships[1]).to have_attributes(
          plan_id: gold.id, customization_name: 'Gold Plus', customization_planned: true, booth_assigned: true,
        )
        expect(sponsorships[2]).to have_attributes(has_plan_id?: false, suspended: true)
      end

      it 'answers a GET with the same overview' do
        expect(connect_call(rpc, request_for(conference.slug), via: :get))
          .to eq(connect_call(rpc, request_for(conference.slug)))
      end

      it 'loads plans and sponsorships in as many queries however many there are' do
        baseline = query_count { connect_call(rpc, request_for(conference.slug)) }
        FactoryBot.create_list(:sponsorship, 3, conference:, plan: gold, accepted_at: Time.zone.now)

        expect(query_count { connect_call(rpc, request_for(conference.slug)) }).to eq(baseline)
      end
    end

    context 'with a restricted staff session' do
      before { sign_in_staff(restricted_staff) }

      it 'returns a conference the staff member is admitted to' do
        expect(connect_call(rpc, request_for(conference.slug)).conference.conference.slug).to eq(conference.slug)
      end

      it 'answers permission_denied for any other conference' do
        other = FactoryBot.create(:conference)

        error = connect_call(rpc, request_for(other.slug))

        expect(error).to have_attributes(status: 403, code: 'permission_denied')
        expect(error.detail(Protobufable::ProblemDetails).type).to eq('https://sponsorships.rubykaigi.org/problems/permission-denied')
      end
    end

    it 'answers unauthenticated without a staff session' do
      expect(connect_call(rpc, request_for(conference.slug))).to have_attributes(code: 'unauthenticated')
    end

    it 'answers unauthenticated before judging the request' do
      expect(connect_call(rpc, request_for('Not A Slug'))).to have_attributes(code: 'unauthenticated')
    end
  end

  describe 'CreateConference' do
    let(:rpc) { connect_method('AdminService', 'CreateConference') }

    def request_with(input) = Rk::SponsorApp::AdminServiceCreateConferenceRequest.new(input:)

    context 'with an unrestricted staff session' do
      before { sign_in_staff(staff) }

      it 'creates the conference from every field of the input' do
        created = connect_call(rpc, request_with(input)).conference

        conference = Conference.find_by!(slug: 'rubykaigi2027')
        expect(conference).to have_attributes(
          name: 'RubyKaigi 2027',
          contact_email_address: 'sponsorships@rubykaigi.example.invalid',
          application_opens_at: Time.utc(2027, 1, 15),
          application_closes_at: Time.utc(2027, 3, 1),
          amendment_closes_at: Time.utc(2027, 3, 15),
          event_submission_starts_at: Time.utc(2027, 2, 1),
          ticket_distribution_starts_at: Time.utc(2027, 4, 1),
          pass_retraction_disables_at: Time.utc(2027, 5, 1),
          no_plan_allowed: false,
          booth_capacity: 30,
          additional_attendees_registration_open: true,
          hidden: false,
          allow_restricted_access: true,
          github_repo_images_path: 'images',
          tito_slug: 'rubykaigi/2027',
          tito_booth_paid_flat_discount_amount: BigDecimal('15000.5'),
        )
        expect(conference.github_repo).to have_attributes(
          name: 'ruby-no-kai/rubykaigi.org', branch: 'master', path: 'data/year_2027/sponsors.yml',
        )
        expect(created).to have_attributes(
          conference: have_attributes(slug: 'rubykaigi2027', name: 'RubyKaigi 2027', booths_offered: true),
          github_repo: 'ruby-no-kai/rubykaigi.org@master:data/year_2027/sponsors.yml',
          github_repo_images_path: 'images',
          tito_slug: 'rubykaigi/2027',
          tito_booth_paid_flat_discount_amount: '15000.5',
          allow_restricted_access: true,
          application_form_url: 'http://www.example.com/conferences/rubykaigi2027/sponsorship/new',
        )
      end

      it 'generates the reception key, and no invite code for a public conference' do
        connect_call(rpc, request_with(input))

        expect(Conference.find_by!(slug: 'rubykaigi2027')).to have_attributes(reception_key: be_present, invite_code: nil)
      end

      it 'generates the invite code of a hidden conference, which the application form URL carries' do
        created = connect_call(rpc, request_with(input(hidden: true))).conference

        invite_code = Conference.find_by!(slug: 'rubykaigi2027').invite_code
        expect(invite_code).to be_present
        expect(created.application_form_url)
          .to eq("http://www.example.com/conferences/rubykaigi2027/sponsorship/new?invite_code=#{invite_code}")
      end

      it 'leaves out what the input leaves out' do
        minimal = Rk::SponsorApp::ConferenceInput.new(
          name: 'RubyKaigi 2027', slug: 'rubykaigi2027', contact_email_address: 'info@rubykaigi.example.invalid',
          booth_capacity: 0, tito_booth_paid_flat_discount_amount: '0',
        )

        created = connect_call(rpc, request_with(minimal)).conference

        expect(Conference.find_by!(slug: 'rubykaigi2027')).to have_attributes(
          application_opens_at: nil, github_repo: nil, github_repo_images_path: nil, tito_slug: nil, booth_capacity: 0,
        )
        expect(created).to have_attributes(
          has_github_repo?: false, has_github_repo_images_path?: false, has_tito_slug?: false,
          tito_booth_paid_flat_discount_amount: '0.0',
          conference: have_attributes(application_opens_at: nil, booths_offered: false),
        )
      end

      it 'creates over binary protobuf too' do
        expect(connect_call(rpc, request_with(input), codec: :proto).conference.conference.slug).to eq('rubykaigi2027')
      end

      it 'answers invalid_argument naming each field that breaks a format rule' do
        error = connect_call(rpc, request_with(input(
          slug: 'RubyKaigi 2027',
          contact_email_address: 'not an address',
          github_repo: 'ruby-no-kai/rubykaigi.org',
          tito_slug: 'rubykaigi',
          booth_capacity: -1,
          tito_booth_paid_flat_discount_amount: '15000.505',
        )))

        expect(error).to have_attributes(status: 400, code: 'invalid_argument')
        expect(violations_of(error)).to contain_exactly(
          ['input.slug', 'STRING_PATTERN'],
          ['input.contactEmailAddress', 'STRING_EMAIL'],
          ['input.githubRepo', 'CONFERENCE_GITHUB_REPO_FORMAT'],
          ['input.titoSlug', 'CONFERENCE_TITO_SLUG_FORMAT'],
          ['input.boothCapacity', 'INT32_GTE'],
          ['input.titoBoothPaidFlatDiscountAmount', 'CONFERENCE_TITO_BOOTH_PAID_FLAT_DISCOUNT_AMOUNT_FORMAT'],
        )
        expect(Conference.count).to eq(0)
      end

      it 'answers invalid_argument for an empty booth capacity or discount, as neither column is nullable' do
        error = connect_call(rpc, request_with(input(booth_capacity: nil, tito_booth_paid_flat_discount_amount: '')))

        expect(bad_request_of(error).field_violations.map { [it.field, it.reason, it.description] }).to contain_exactly(
          ['input.boothCapacity', 'REQUIRED', 'value is required'],
          ['input.titoBoothPaidFlatDiscountAmount', 'CONFERENCE_TITO_BOOTH_PAID_FLAT_DISCOUNT_AMOUNT_FORMAT',
           'must be an amount such as 1000 or 1000.50'],
        )
      end

      it 'names the field as a binary request spells it, with the message its rule declares' do
        error = connect_call(rpc, request_with(input(tito_slug: 'rubykaigi')), codec: :proto)

        expect(bad_request_of(error).field_violations.map { [it.field, it.reason, it.description] })
          .to eq([['input.tito_slug', 'CONFERENCE_TITO_SLUG_FORMAT', 'must be account_slug/event_slug']])
      end

      it 'answers invalid_argument for a missing or blank name' do
        expect(violations_of(connect_call(rpc, request_with(input(name: ''))))).to eq([['input.name', 'REQUIRED']])
        expect(violations_of(connect_call(rpc, request_with(input(name: '  ')))))
          .to eq([['input.name', 'CONFERENCE_NAME_NOT_BLANK']])
      end

      it 'answers invalid_argument for an empty optional string, which is set rather than absent' do
        expect(violations_of(connect_call(rpc, request_with(input(github_repo: '', github_repo_images_path: ''))))).to contain_exactly(
          ['input.githubRepo', 'CONFERENCE_GITHUB_REPO_FORMAT'],
          ['input.githubRepoImagesPath', 'STRING_MIN_LEN'],
        )
      end

      it 'answers invalid_argument without an input' do
        expect(violations_of(connect_call(rpc, request_with(nil)))).to eq([['input', 'REQUIRED']])
      end

      it 'answers the invalid-record problem on the slug field for a slug another conference has' do
        FactoryBot.create(:conference, slug: 'rubykaigi2027')

        error = connect_call(rpc, request_with(input))

        expect(error).to have_attributes(status: 400, code: 'invalid_argument')
        expect(error.detail(Protobufable::ProblemDetails)).to have_attributes(
          type: 'https://sponsorships.rubykaigi.org/problems/invalid-record',
          status: 422,
        )
        expect(bad_request_of(error).field_violations.map { [it.field, it.reason, it.description] })
          .to eq([['input.slug', 'TAKEN', 'has already been taken']])
        expect(Conference.count).to eq(1)
      end

      it 'answers aborted with the conflict problem when a concurrent save takes the slug after validation' do
        allow(Conference).to receive(:new).and_wrap_original do |new_conference, *args|
          new_conference.call(*args).tap do |conference|
            allow(conference).to receive(:valid?).and_wrap_original do |valid, *valid_args|
              # insert! bypasses Conference.new, which this example wraps.
              rival = {name: 'Rival', slug: 'rubykaigi2027', reception_key: 'rival'}
              valid.call(*valid_args).tap { Conference.insert!(rival) } # rubocop:disable Rails/SkipsModelValidations
            end
          end
        end

        error = connect_call(rpc, request_with(input))

        expect(error).to have_attributes(status: 409, code: 'aborted')
        expect(error.detail(Protobufable::ProblemDetails).type).to eq('https://sponsorships.rubykaigi.org/problems/conflict')
      end

      it 'refuses GET, as creating has side effects' do
        get "#{rpc.path}?#{URI.encode_www_form(connect: 'v1', encoding: 'json', message: request_with(input).to_json)}"

        expect(response).to have_http_status(:method_not_allowed)
      end
    end

    it 'answers permission_denied to restricted staff' do
      sign_in_staff(restricted_staff)

      error = connect_call(rpc, request_with(input(github_repo: 'ruby-no-kai/rubykaigi-admitted@main:data')))

      expect(error).to have_attributes(status: 403, code: 'permission_denied')
      expect(Conference.count).to eq(0)
    end

    it 'answers unauthenticated before judging the request' do
      expect(connect_call(rpc, request_with(input(slug: 'Not A Slug')))).to have_attributes(code: 'unauthenticated')
    end
  end

  describe 'UpdateConference' do
    let(:rpc) { connect_method('AdminService', 'UpdateConference') }
    let!(:conference) do
      FactoryBot.create(:conference, slug: 'rubykaigi2026', name: 'RubyKaigi 2026', allow_restricted_access: true,
        github_repo: 'ruby-no-kai/rubykaigi-admitted@main:data/sponsors.yml', tito_slug: 'rubykaigi/2026')
    end

    def request_with(input, slug: 'rubykaigi2026')
      Rk::SponsorApp::AdminServiceUpdateConferenceRequest.new(conference_slug: slug, input:)
    end

    context 'with an unrestricted staff session' do
      before { sign_in_staff(staff) }

      it 'replaces every field, the slug included' do
        updated = connect_call(rpc, request_with(input)).conference

        expect(conference.reload).to have_attributes(
          slug: 'rubykaigi2027',
          name: 'RubyKaigi 2027',
          application_opens_at: Time.utc(2027, 1, 15),
          booth_capacity: 30,
          tito_slug: 'rubykaigi/2027',
          tito_booth_paid_flat_discount_amount: BigDecimal('15000.5'),
        )
        expect(updated.conference.slug).to eq('rubykaigi2027')
      end

      it 'returns what GetConference returns afterwards' do
        updated = connect_call(rpc, request_with(input)).conference
        get_request = Rk::SponsorApp::AdminServiceGetConferenceRequest.new(conference_slug: 'rubykaigi2027')

        expect(connect_call(connect_method('AdminService', 'GetConference'), get_request).conference).to eq(updated)
      end

      it 'clears what the input leaves out' do
        connect_call(rpc, request_with(input(
          application_opens_at: nil, github_repo: nil, github_repo_images_path: nil, tito_slug: nil,
        )))

        expect(conference.reload).to have_attributes(
          application_opens_at: nil, github_repo: nil, github_repo_images_path: nil, tito_slug: nil,
        )
      end

      it 'keeps the generated keys, generating an invite code once the conference is hidden' do
        reception_key = conference.reception_key

        connect_call(rpc, request_with(input(hidden: true)))

        expect(conference.reload).to have_attributes(reception_key:, invite_code: be_present)
      end

      it 'updates over binary protobuf too' do
        expect(connect_call(rpc, request_with(input), codec: :proto).conference.conference.slug).to eq('rubykaigi2027')
        expect(conference.reload.slug).to eq('rubykaigi2027')
      end

      it 'answers not_found for a slug no conference has' do
        expect(connect_call(rpc, request_with(input, slug: 'rubykaigi1999'))).to have_attributes(status: 404, code: 'not_found')
      end

      it 'answers invalid_argument for a conference slug that breaks its rule' do
        error = connect_call(rpc, request_with(input, slug: 'Not A Slug'))

        expect(error).to have_attributes(status: 400, code: 'invalid_argument')
        expect(violations_of(error)).to eq([['conferenceSlug', 'STRING_PATTERN']])
      end

      it 'answers the invalid-record problem for a slug another conference has, leaving the record as it was' do
        FactoryBot.create(:conference, slug: 'rubykaigi2027')

        error = connect_call(rpc, request_with(input))

        expect(violations_of(error)).to eq([['input.slug', 'TAKEN']])
        expect(conference.reload).to have_attributes(slug: 'rubykaigi2026', name: 'RubyKaigi 2026')
      end

      it 'leaves the record as it was on a broken rule' do
        error = connect_call(rpc, request_with(input(tito_slug: 'rubykaigi')))

        expect(violations_of(error)).to eq([['input.titoSlug', 'CONFERENCE_TITO_SLUG_FORMAT']])
        expect(conference.reload).to have_attributes(name: 'RubyKaigi 2026', tito_slug: 'rubykaigi/2026')
      end
    end

    it 'answers permission_denied to restricted staff, even for a conference they may manage' do
      sign_in_staff(restricted_staff)
      get_request = Rk::SponsorApp::AdminServiceGetConferenceRequest.new(conference_slug: 'rubykaigi2026')
      expect(connect_call(connect_method('AdminService', 'GetConference'), get_request)).not_to be_a(ConnectHelper::ConnectError)

      error = connect_call(rpc, request_with(input(github_repo: 'ruby-no-kai/rubykaigi-admitted@main:data/sponsors.yml')))

      expect(error).to have_attributes(status: 403, code: 'permission_denied')
      expect(conference.reload.name).to eq('RubyKaigi 2026')
    end

    it 'answers unauthenticated before judging the request' do
      expect(connect_call(rpc, request_with(input(slug: 'Not A Slug')))).to have_attributes(code: 'unauthenticated')
      expect(conference.reload.name).to eq('RubyKaigi 2026')
    end
  end

  describe 'GetAttendeesKeeper' do
    let(:rpc) { connect_method('AdminService', 'GetAttendeesKeeper') }
    let(:conference) do
      FactoryBot.create(:conference, allow_restricted_access: true, github_repo: 'ruby-no-kai/rubykaigi-admitted@main:data')
    end
    let(:ruby) { FactoryBot.create(:plan, conference:, name: 'Ruby', number_of_guests: 5) }
    let(:gold) { FactoryBot.create(:plan, conference:, name: 'Gold', number_of_guests: 2) }

    let!(:ruby_sponsor) do
      FactoryBot.create(:sponsorship, conference:, plan: ruby, accepted_at: Time.zone.now, number_of_additional_attendees: 1)
    end
    let!(:gold_sponsor) do
      FactoryBot.create(:sponsorship, conference:, plan: gold, accepted_at: Time.zone.now, number_of_additional_attendees: nil)
    end
    let!(:another_gold_sponsor) do
      FactoryBot.create(:sponsorship, conference:, plan: gold, accepted_at: Time.zone.now, number_of_additional_attendees: 4)
    end

    def request_for(slug) = Rk::SponsorApp::AdminServiceGetAttendeesKeeperRequest.new(conference_slug: slug)

    before do
      FactoryBot.create(:sponsorship, conference:, plan: gold, number_of_additional_attendees: 3)
      FactoryBot.create(:sponsorship, conference:, plan: gold, accepted_at: Time.zone.now, withdrawn_at: Time.zone.now)
    end

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'counts the tickets of active sponsorships, most tickets first, then oldest first' do
        response_message = connect_call(rpc, request_for(conference.slug))

        expect(response_message).to have_attributes(included_attendees: 9, additional_attendees: 5, total_attendees: 14)
        expect(response_message.sponsorships.map { [it.sponsorship.id, it.included_attendees, it.additional_attendees, it.total_attendees] })
          .to eq([
            [ruby_sponsor.id, 5, 1, 6],
            [another_gold_sponsor.id, 2, 4, 6],
            [gold_sponsor.id, 2, 0, 2],
          ])
        expect(response_message.sponsorships.first.sponsorship).to have_attributes(
          name: be_present, state: :SPONSORSHIP_STATE_ACTIVE, organization: have_attributes(domain: be_present),
        )
      end

      it 'answers GET, in JSON and binary, alike' do
        expected = connect_call(rpc, request_for(conference.slug))

        expect(connect_call(rpc, request_for(conference.slug), via: :get)).to eq(expected)
        expect(connect_call(rpc, request_for(conference.slug), via: :get, codec: :proto)).to eq(expected)
      end

      it 'answers zero for a conference without active sponsorships' do
        expect(connect_call(rpc, request_for(FactoryBot.create(:conference).slug))).to eq(
          Rk::SponsorApp::AdminServiceGetAttendeesKeeperResponse.new,
        )
      end

      it 'loads the sponsorships in as many queries however many there are' do
        baseline = query_count { connect_call(rpc, request_for(conference.slug)) }
        FactoryBot.create_list(:sponsorship, 3, conference:, plan: gold, accepted_at: Time.zone.now)

        expect(query_count { connect_call(rpc, request_for(conference.slug)) }).to eq(baseline)
      end

      it 'answers not_found for a slug no conference has' do
        expect(connect_call(rpc, request_for('rubykaigi1999'))).to have_attributes(code: 'not_found')
      end

      it 'answers invalid_argument for a conference slug that breaks its rule' do
        error = connect_call(rpc, request_for('Not A Slug'))

        expect(error).to have_attributes(status: 400, code: 'invalid_argument')
        expect(violations_of(error)).to eq([['conferenceSlug', 'STRING_PATTERN']])
      end
    end

    it 'serves restricted staff the conferences they may manage, and no other' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_for(conference.slug)).total_attendees).to eq(14)
      expect(connect_call(rpc, request_for(FactoryBot.create(:conference).slug))).to have_attributes(code: 'permission_denied')
    end

    it 'answers unauthenticated before judging the request' do
      expect(connect_call(rpc, request_for('Not A Slug'))).to have_attributes(status: 401, code: 'unauthenticated')
    end
  end

  describe 'ListSponsorshipTableRows' do
    let(:rpc) { connect_method('AdminService', 'ListSponsorshipTableRows') }
    let(:conference) do
      FactoryBot.create(:conference, allow_restricted_access: true, github_repo: 'ruby-no-kai/rubykaigi-admitted@main:data')
    end
    let(:gold) { FactoryBot.create(:plan, conference:, name: 'Gold') }

    let!(:customized) do
      FactoryBot.create(:sponsorship, conference:, plan: gold, customization: true, customization_name: 'Gold Plus').tap do
        it.create_billing_request!(body: 'Send the invoice by March')
        it.create_customization_request!(body: 'Two booths, please')
        it.create_note!(body: 'Thanks')
      end
    end
    let!(:planned) { FactoryBot.create(:sponsorship, conference:, plan: gold, customization_name: 'Gold Max') }
    let!(:undetermined) { FactoryBot.create(:sponsorship, conference:, plan: nil, withdrawn_at: Time.zone.now) }

    def request_for(slug) = Rk::SponsorApp::AdminServiceListSponsorshipTableRowsRequest.new(conference_slug: slug)

    before { FactoryBot.create(:sponsorship, conference: FactoryBot.create(:conference), plan: nil) }

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'lists every sponsorship of the conference, oldest first, withdrawn ones included' do
        rows = connect_call(rpc, request_for(conference.slug)).sponsorship_table_rows

        expect(rows.map { it.sponsorship.id }).to eq([customized.id, planned.id, undetermined.id])
        expect(rows.last.sponsorship.state).to eq(:SPONSORSHIP_STATE_WITHDRAWN)
      end

      it 'carries the plan, the name the sponsor is published under and the notes' do
        rows = connect_call(rpc, request_for(conference.slug)).sponsorship_table_rows

        expect(rows[0]).to have_attributes(
          plan_name: 'Gold',
          displayed_plan_name: 'Gold Plus',
          billing_request: 'Send the invoice by March',
          customization_request: 'Two booths, please',
          note: 'Thanks',
        )
        expect(rows[1]).to have_attributes(
          plan_name: 'Gold', displayed_plan_name: 'Gold', has_billing_request?: false, has_customization_request?: false, has_note?: false,
        )
        expect(rows[2]).to have_attributes(has_plan_name?: false, has_displayed_plan_name?: false)
      end

      it 'answers GET, in JSON and binary, alike' do
        expected = connect_call(rpc, request_for(conference.slug))

        expect(connect_call(rpc, request_for(conference.slug), via: :get)).to eq(expected)
        expect(connect_call(rpc, request_for(conference.slug), via: :get, codec: :proto)).to eq(expected)
      end

      it 'loads the rows in as many queries however many there are' do
        baseline = query_count { connect_call(rpc, request_for(conference.slug)) }
        FactoryBot.create_list(:sponsorship, 3, conference:, plan: gold).each { it.create_note!(body: 'Hello') }

        expect(query_count { connect_call(rpc, request_for(conference.slug)) }).to eq(baseline)
      end

      it 'answers invalid_argument for a conference slug that breaks its rule' do
        error = connect_call(rpc, request_for('Not A Slug'))

        expect(error).to have_attributes(status: 400, code: 'invalid_argument')
        expect(violations_of(error)).to eq([['conferenceSlug', 'STRING_PATTERN']])
      end
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_for(conference.slug)).sponsorship_table_rows.size).to eq(3)
      expect(connect_call(rpc, request_for(FactoryBot.create(:conference).slug))).to have_attributes(code: 'permission_denied')
    end

    it 'answers unauthenticated before judging the request' do
      expect(connect_call(rpc, request_for('Not A Slug'))).to have_attributes(code: 'unauthenticated')
    end
  end
end
