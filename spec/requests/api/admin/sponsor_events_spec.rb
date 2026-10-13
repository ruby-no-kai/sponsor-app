# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AdminService sponsor events', type: :request do
  let(:staff) { FactoryBot.create(:staff, login: 'editor') }
  let(:restricted_staff) { FactoryBot.create(:staff, restricted_repos: ['ruby-no-kai/rubykaigi-admitted']) }
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:plan) { conference.plans.first }
  let(:host) { FactoryBot.create(:sponsorship, conference:, plan:, name: 'Host') }
  let(:co_host) { FactoryBot.create(:sponsorship, conference:, plan:, name: 'Co-host') }
  let(:other_conference) { FactoryBot.create(:conference, :full) }
  let(:starts_at) { Time.zone.parse('2048-09-10 19:00:00') }
  let(:policy_acknowledged_at) { Time.zone.parse('2048-07-01 10:00:00') }

  let!(:event) do
    FactoryBot.create(:sponsor_event, :pending, :with_details,
      sponsorship: host, title: 'Ruby Night', slug: 'host-1', starts_at:, url: 'https://night.example.invalid',
      link_name: 'Registration', admin_comment: 'Bring your badge', co_host_sponsorship_ids: [co_host.id],
      policy_acknowledged_at:)
  end

  before do
    allow(ProcessSponsorEventEditJob).to receive(:perform_later)
  end

  def summary(sponsorship) = Api::SponsorshipSummaryResource.new(sponsorship.reload).as_protobuf

  def expected_event
    Rk::SponsorApp::AdminSponsorEvent.new(
      id: event.id,
      slug: 'host-1',
      title: 'Ruby Night',
      status: :SPONSOR_EVENT_STATUS_PENDING,
      starts_at: Google::Protobuf::Timestamp.from_time(starts_at),
      url: 'https://night.example.invalid',
      link_name: 'Registration',
      price: 'Free',
      capacity: '100 people',
      location_en: 'Tokyo',
      location_local: '東京',
      sponsorship: summary(host),
      co_hosts: [summary(co_host)],
      admin_comment: 'Bring your badge',
      policy_acknowledged_at: Google::Protobuf::Timestamp.from_time(policy_acknowledged_at),
      hero_image_uploaded: false,
    )
  end

  def elsewhere_sponsorship = FactoryBot.create(:sponsorship, conference: other_conference, plan: other_conference.plans.first)

  def create_event(**attributes)
    FactoryBot.create(:sponsor_event, sponsorship: FactoryBot.create(:sponsorship, conference:, plan:), **attributes)
  end

  describe 'ListSponsorEvents' do
    let(:rpc) { connect_method('AdminService', 'ListSponsorEvents') }

    def request_for(slug = conference.slug) = Rk::SponsorApp::AdminServiceListSponsorEventsRequest.new(conference_slug: slug)

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it "lists the conference's events by status, then earliest start first" do
        withdrawn = create_event(status: :withdrawn, starts_at: starts_at - 2.days)
        later = create_event(status: :pending, starts_at: starts_at + 1.day)
        rejected = create_event(status: :rejected, starts_at: starts_at - 1.day)
        accepted = create_event(status: :accepted, starts_at: starts_at + 2.days)
        FactoryBot.create(:sponsor_event, sponsorship: elsewhere_sponsorship)

        events = connect_call(rpc, request_for).sponsor_events

        expect(events.map(&:id)).to eq([event, later, accepted, rejected, withdrawn].map(&:id))
        expect(events.map(&:status)).to eq(%i(SPONSOR_EVENT_STATUS_PENDING SPONSOR_EVENT_STATUS_PENDING SPONSOR_EVENT_STATUS_ACCEPTED SPONSOR_EVENT_STATUS_REJECTED SPONSOR_EVENT_STATUS_WITHDRAWN))
        expect(events.first).to eq(expected_event)
      end

      it 'lists a withdrawn co-host, which the conference website leaves out, as withdrawn' do
        co_host.withdraw.save!

        co_hosts = connect_call(rpc, request_for).sponsor_events.sole.co_hosts

        expect(co_hosts.map { [it.id, it.state] }).to eq([[co_host.id, :SPONSORSHIP_STATE_WITHDRAWN]])
      end

      it 'answers GET, in JSON and binary, and binary POST alike' do
        expected = connect_call(rpc, request_for)

        expect(connect_call(rpc, request_for, via: :get)).to eq(expected)
        expect(connect_call(rpc, request_for, via: :get, codec: :proto)).to eq(expected)
        expect(connect_call(rpc, request_for, codec: :proto)).to eq(expected)
      end

      it 'loads hosts, co-hosts and hero images in as many queries however many events there are' do
        baseline = query_count { connect_call(rpc, request_for) }
        3.times do
          FactoryBot.create(:sponsor_event_asset_file, sponsorship: host, sponsor_event: create_event(co_host_sponsorship_ids: [host.id, co_host.id]))
        end

        expect(query_count { connect_call(rpc, request_for) }).to eq(baseline)
      end

      it 'returns no events for a conference without any' do
        expect(connect_call(rpc, request_for(other_conference.slug)).sponsor_events).to be_empty
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

    it 'lists the events of a conference restricted staff are admitted to' do
      conference.update!(allow_restricted_access: true, github_repo: 'ruby-no-kai/rubykaigi-admitted@main:data')
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_for).sponsor_events.map(&:id)).to eq([event.id])
    end
  end

  describe 'GetSponsorEvent' do
    let(:rpc) { connect_method('AdminService', 'GetSponsorEvent') }

    def request_for(sponsor_event_id, slug: conference.slug)
      Rk::SponsorApp::AdminServiceGetSponsorEventRequest.new(conference_slug: slug, sponsor_event_id:)
    end

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'returns every field of the event' do
        expect(connect_call(rpc, request_for(event.id)).sponsor_event).to eq(expected_event)
      end

      it 'tells whether a hero image was uploaded, and leaves out a policy never agreed to' do
        FactoryBot.create(:sponsor_event_asset_file, sponsorship: host, sponsor_event: event)
        event.update_columns(policy_acknowledged_at: nil) # rubocop:disable Rails/SkipsModelValidations

        expect(connect_call(rpc, request_for(event.id)).sponsor_event).to have_attributes(
          hero_image_uploaded: true,
          policy_acknowledged_at: nil,
        )
      end

      it 'lists co-hosts in the order stored, leaving out an ID of another conference' do
        elsewhere = elsewhere_sponsorship
        second = FactoryBot.create(:sponsorship, conference:, plan:)
        event.update_columns(co_host_sponsorship_ids: [second.id, elsewhere.id, co_host.id]) # rubocop:disable Rails/SkipsModelValidations

        expect(connect_call(rpc, request_for(event.id)).sponsor_event.co_hosts.map(&:id)).to eq([second.id, co_host.id])
      end

      it 'answers GET, in JSON and binary, and binary POST alike' do
        expected = connect_call(rpc, request_for(event.id))

        expect(connect_call(rpc, request_for(event.id), via: :get)).to eq(expected)
        expect(connect_call(rpc, request_for(event.id), via: :get, codec: :proto)).to eq(expected)
        expect(connect_call(rpc, request_for(event.id), codec: :proto)).to eq(expected)
      end

      it 'answers not_found for an event of another conference' do
        elsewhere = FactoryBot.create(:sponsor_event, sponsorship: elsewhere_sponsorship)

        error = connect_call(rpc, request_for(elsewhere.id))

        expect(error).to have_attributes(status: 404, code: 'not_found')
        expect(problem_type_of(error)).to eq('not-found')
      end

      it "answers not_found when the slug names a conference other than the event's" do
        expect(connect_call(rpc, request_for(event.id, slug: other_conference.slug))).to have_attributes(code: 'not_found')
      end

      it 'answers invalid_argument for an event ID that cannot exist' do
        expect(violations_of(connect_call(rpc, request_for(0)))).to eq([['sponsorEventId', 'INT64_GT']])
      end
    end

    it 'answers unauthenticated without a staff session, before judging the request' do
      expect(connect_call(rpc, request_for(0))).to have_attributes(code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_for(event.id))).to have_attributes(code: 'permission_denied')
    end
  end

  describe 'UpdateSponsorEvent' do
    let(:rpc) { connect_method('AdminService', 'UpdateSponsorEvent') }
    let(:new_starts_at) { Time.zone.parse('2048-09-11 18:30:00') }
    let(:second_co_host) { FactoryBot.create(:sponsorship, conference:, plan:) }

    def input(**fields)
      Rk::SponsorApp::AdminSponsorEventInput.new(
        title: 'Ruby Evening',
        slug: 'host-evening',
        starts_at: Google::Protobuf::Timestamp.from_time(new_starts_at),
        url: 'http://evening.example.invalid/register',
        link_name: 'Details',
        price: '1000 JPY',
        capacity: '50',
        location_en: 'Shinjuku',
        location_local: '新宿',
        status: :SPONSOR_EVENT_STATUS_ACCEPTED,
        co_host_sponsorship_ids: [second_co_host.id, co_host.id],
        admin_comment: 'Accepted',
        **fields,
      )
    end

    def request_with(input, sponsor_event_id: event.id)
      Rk::SponsorApp::AdminServiceUpdateSponsorEventRequest.new(conference_slug: conference.slug, sponsor_event_id:, input:)
    end

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'replaces every field, recording the staff member in the editing history' do
        result = connect_call(rpc, request_with(input)).sponsor_event

        expect(event.reload).to have_attributes(
          title: 'Ruby Evening', slug: 'host-evening', starts_at: new_starts_at, url: 'http://evening.example.invalid/register',
          link_name: 'Details', price: '1000 JPY', capacity: '50', location_en: 'Shinjuku', location_local: '新宿',
          status: 'accepted', co_host_sponsorship_ids: [second_co_host.id, co_host.id], admin_comment: 'Accepted',
          policy_acknowledged_at:,
        )
        expect(result).to have_attributes(id: event.id, title: 'Ruby Evening', status: :SPONSOR_EVENT_STATUS_ACCEPTED)
        expect(result.co_hosts.map(&:id)).to eq([second_co_host.id, co_host.id])

        history = event.editing_histories.reorder(:id).last
        expect(history.staff).to eq(staff)
        expect(history.diff).to include(['~', 'status', 'pending', 'accepted'])
        expect(ProcessSponsorEventEditJob).to have_received(:perform_later).with(history)
      end

      it 'returns what GetSponsorEvent returns afterwards' do
        updated = connect_call(rpc, request_with(input(starts_at: Google::Protobuf::Timestamp.new(seconds: new_starts_at.to_i, nanos: 123_456_789)))).sponsor_event
        get_request = Rk::SponsorApp::AdminServiceGetSponsorEventRequest.new(conference_slug: conference.slug, sponsor_event_id: event.id)

        expect(connect_call(connect_method('AdminService', 'GetSponsorEvent'), get_request).sponsor_event).to eq(updated)
      end

      SponsorEvent.statuses.each_key do |status|
        it "stores #{status} and reads it back" do
          value = Api::AdminSponsorEventResource::STATUSES.fetch(status)

          expect(connect_call(rpc, request_with(input(status: value))).sponsor_event.status).to eq(value)
          expect(event.reload.status).to eq(status)
        end
      end

      it 'removes every co-host' do
        expect(connect_call(rpc, request_with(input(co_host_sponsorship_ids: []))).sponsor_event.co_hosts).to be_empty
        expect(event.reload.co_host_sponsorship_ids).to eq([])
      end

      it 'updates over binary protobuf too' do
        expect(connect_call(rpc, request_with(input), codec: :proto).sponsor_event.title).to eq('Ruby Evening')
      end

      it 'changes a withdrawn event' do
        event.update!(status: :withdrawn)

        expect(connect_call(rpc, request_with(input(status: :SPONSOR_EVENT_STATUS_WITHDRAWN))).sponsor_event.title).to eq('Ruby Evening')
      end

      it 'answers the invalid-record problem for a co-host of another conference, changing nothing' do
        elsewhere = elsewhere_sponsorship

        error = connect_call(rpc, request_with(input(co_host_sponsorship_ids: [co_host.id, elsewhere.id])))

        expect(error).to have_attributes(status: 400, code: 'invalid_argument')
        expect(problem_type_of(error)).to eq('invalid-record')
        expect(violations_of(error)).to eq([['input.coHostSponsorshipIds', 'INVALID_VALUE']])
        expect(event.reload).to have_attributes(title: 'Ruby Night', co_host_sponsorship_ids: [co_host.id])
        expect(ProcessSponsorEventEditJob).not_to have_received(:perform_later)
      end

      it 'answers the invalid-record problem for a slug another event of the conference has' do
        create_event(slug: 'taken')

        error = connect_call(rpc, request_with(input(slug: 'taken')))

        expect(problem_type_of(error)).to eq('invalid-record')
        expect(violations_of(error)).to eq([['input.slug', 'TAKEN']])
        expect(event.reload.slug).to eq('host-1')
      end

      it 'takes a slug an event of another conference has' do
        FactoryBot.create(:sponsor_event, slug: 'shared', sponsorship: elsewhere_sponsorship)

        expect(connect_call(rpc, request_with(input(slug: 'shared'))).sponsor_event.slug).to eq('shared')
      end

      it 'answers not_found for an event of another conference, leaving it as it was' do
        elsewhere = FactoryBot.create(:sponsor_event, title: 'Elsewhere', sponsorship: elsewhere_sponsorship)

        expect(connect_call(rpc, request_with(input, sponsor_event_id: elsewhere.id))).to have_attributes(code: 'not_found')
        expect(elsewhere.reload.title).to eq('Elsewhere')
        expect(ProcessSponsorEventEditJob).not_to have_received(:perform_later)
      end

      it 'answers invalid_argument with a violation per broken rule, changing nothing' do
        error = connect_call(rpc, request_with(input(
          title: ' ',
          slug: '',
          starts_at: nil,
          url: 'ftp://night.example.invalid',
          status: :SPONSOR_EVENT_STATUS_UNSPECIFIED,
          co_host_sponsorship_ids: [co_host.id, co_host.id, 0],
        )))

        expect(error).to have_attributes(status: 400, code: 'invalid_argument')
        expect(violations_of(error)).to contain_exactly(
          ['input.title', 'ADMIN_SPONSOR_EVENT_INPUT_TITLE_NOT_BLANK'],
          ['input.slug', 'REQUIRED'],
          ['input.startsAt', 'REQUIRED'],
          ['input.url', 'ADMIN_SPONSOR_EVENT_INPUT_URL_FORMAT'],
          ['input.status', 'ENUM_NOT_IN'],
          ['input.coHostSponsorshipIds', 'REPEATED_UNIQUE'],
          ['input.coHostSponsorshipIds[2]', 'INT64_GT'],
        )
        expect(event.reload.title).to eq('Ruby Night')
        expect(ProcessSponsorEventEditJob).not_to have_received(:perform_later)
      end

      it 'answers invalid_argument for a status SponsorEventStatus does not define' do
        error = connect_call(rpc, request_with(input(status: 99)), codec: :proto)

        expect(violations_of(error)).to eq([['input.status', 'ENUM_DEFINED_ONLY']])
      end

      it 'answers invalid_argument for a start ProtoJSON cannot spell' do
        error = connect_call(rpc, request_with(input(starts_at: Google::Protobuf::Timestamp.new(seconds: 10**15))), codec: :proto)

        expect(violations_of(error)).to eq([['input.starts_at', 'TIMESTAMP_GTE_LTE']])
      end

      it 'answers invalid_argument without an input' do
        expect(violations_of(connect_call(rpc, request_with(nil)))).to eq([['input', 'REQUIRED']])
      end

      it 'refuses GET, as updating has side effects' do
        get "#{rpc.path}?#{URI.encode_www_form(connect: 'v1', encoding: 'json', message: request_with(input).to_json)}"

        expect(response).to have_http_status(:method_not_allowed)
      end
    end

    it 'answers unauthenticated before judging the request' do
      expect(connect_call(rpc, request_with(input(title: '')))).to have_attributes(code: 'unauthenticated')
      expect(ProcessSponsorEventEditJob).not_to have_received(:perform_later)
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_with(input))).to have_attributes(code: 'permission_denied')
      expect(event.reload.title).to eq('Ruby Night')
    end
  end
end
