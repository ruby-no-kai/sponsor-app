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

        expect(response_message.conferences.map(&:slug)).to eq([newer.slug, older.slug])
        expect(response_message.conferences.last).to have_attributes(
          name: older.name,
          contact_email_address: older.contact_email_address,
          application_opens_at: Google::Protobuf::Timestamp.new(seconds: Time.utc(2026, 1, 15).to_i),
          booths_offered: true,
        )
        expect(response_message.conferences.first).to have_attributes(application_opens_at: nil, booths_offered: false)
      end

      it 'answers a GET with the same conferences' do
        expect(connect_call(rpc, request_message, via: :get).conferences.map(&:slug)).to eq([newer.slug, older.slug])
      end

      it 'answers binary protobuf in binary' do
        response_message = connect_call(rpc, request_message, codec: :proto)

        expect(response.media_type).to eq('application/proto')
        expect(response_message.conferences.map(&:slug)).to eq([newer.slug, older.slug])
      end

      it 'answers ProtoJSON in lowerCamelCase, leaving unset fields out' do
        connect_call(rpc, request_message)

        conference = response.parsed_body.fetch('conferences').first
        expect(conference).to include('slug' => newer.slug, 'contactEmailAddress' => newer.contact_email_address)
        expect(conference).not_to have_key('applicationOpensAt')
      end
    end

    it 'lists only the conferences a restricted staff member may manage' do
      admitted = FactoryBot.create(:conference, allow_restricted_access: true, github_repo: 'ruby-no-kai/rubykaigi-admitted@main:data')
      FactoryBot.create(:conference, allow_restricted_access: false, github_repo: 'ruby-no-kai/rubykaigi-admitted@main:data')
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_message).conferences.map(&:slug)).to eq([admitted.slug])
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
        expect(connect_call(rpc, request_for(conference.slug)).conference)
          .to have_attributes(slug: conference.slug, name: conference.name)
      end

      it 'returns the conference over GET, JSON and binary' do
        expect(connect_call(rpc, request_for(conference.slug), via: :get).conference.slug).to eq(conference.slug)
        expect(connect_call(rpc, request_for(conference.slug), via: :get, codec: :proto).conference.slug).to eq(conference.slug)
      end

      it 'returns the conference over POST binary' do
        expect(connect_call(rpc, request_for(conference.slug), codec: :proto).conference.slug).to eq(conference.slug)
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

    context 'with a restricted staff session' do
      before { sign_in_staff(restricted_staff) }

      it 'returns a conference the staff member is admitted to' do
        expect(connect_call(rpc, request_for(conference.slug)).conference.slug).to eq(conference.slug)
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
