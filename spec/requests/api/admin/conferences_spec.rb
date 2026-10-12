# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AdminService conferences', type: :request do
  let(:staff) { FactoryBot.create(:staff) }
  let(:restricted_staff) { FactoryBot.create(:staff, restricted_repos: ['ruby-no-kai/rubykaigi-admitted']) }

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

    def query_count(&)
      count = 0
      counter = ->(*, payload) { count += 1 unless payload[:name] == 'SCHEMA' || payload[:cached] }
      ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &)
      count
    end

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
end
