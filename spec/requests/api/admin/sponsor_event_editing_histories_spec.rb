# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AdminService sponsor event editing history', type: :request do
  let(:staff) { FactoryBot.create(:staff, login: 'editor') }
  let(:restricted_staff) { FactoryBot.create(:staff, restricted_repos: ['ruby-no-kai/rubykaigi-admitted']) }
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first) }
  let(:event) { FactoryBot.create(:sponsor_event, sponsorship:, title: 'Before') }
  let(:rpc) { connect_method('AdminService', 'ListSponsorEventEditingHistory') }

  def request_for(event)
    Rk::SponsorApp::AdminServiceListSponsorEventEditingHistoryRequest.new(conference_slug: conference.slug, sponsor_event_id: event.id)
  end

  def value(ruby)
    Google::Protobuf::Value.from_ruby(ruby)
  end

  context 'with a staff session' do
    before { sign_in_staff(staff) }

    it 'lists the saves newest first, with the staff member and the old and new values' do
      submitted = event.editing_histories.sole
      event.update!(title: 'After', status: :accepted, staff:)
      event.staff = nil
      event.update!(co_host_sponsorship_ids: [sponsorship.id])

      entries = connect_call(rpc, request_for(event)).entries.to_a

      expect(entries.map(&:has_staff_login?)).to eq([false, true, false])
      expect(entries.second.staff_login).to eq('editor')
      expect(entries.last).to have_attributes(id: submitted.id, created_at: Google::Protobuf::Timestamp.from_time(submitted.created_at.to_time))

      edit = entries.second.changes.index_by(&:path)
      expect(edit.fetch('title')).to have_attributes(operation: :OPERATION_CHANGED, old_value: value('Before'), new_value: value('After'))
      expect(edit.fetch('status')).to have_attributes(old_value: value('pending'), new_value: value('accepted'))
      expect(entries.first.changes.map { [it.operation, it.path, it.new_value] }).to eq(
        [[:OPERATION_ADDED, 'co_host_sponsorship_ids[0]', value(sponsorship.id)]],
      )
    end

    it 'answers GET, in JSON and binary, and binary POST alike' do
      event.update!(title: 'After', staff:)
      expected = connect_call(rpc, request_for(event))

      expect(connect_call(rpc, request_for(event), via: :get)).to eq(expected)
      expect(connect_call(rpc, request_for(event), via: :get, codec: :proto)).to eq(expected)
      expect(connect_call(rpc, request_for(event), codec: :proto)).to eq(expected)
    end

    it 'answers not_found for an event of another conference' do
      other_conference = FactoryBot.create(:conference, :full)
      elsewhere_sponsorship = FactoryBot.create(:sponsorship, conference: other_conference, plan: other_conference.plans.first)
      elsewhere = FactoryBot.create(:sponsor_event, sponsorship: elsewhere_sponsorship)

      expect(connect_call(rpc, request_for(elsewhere))).to have_attributes(status: 404, code: 'not_found')
    end

    it 'answers invalid_argument for an event ID that cannot exist' do
      error = connect_call(rpc, Rk::SponsorApp::AdminServiceListSponsorEventEditingHistoryRequest.new(conference_slug: conference.slug, sponsor_event_id: 0))

      expect(error).to have_attributes(status: 400, code: 'invalid_argument')
      expect(violations_of(error)).to eq([['sponsorEventId', 'INT64_GT']])
    end
  end

  it 'answers unauthenticated without a staff session, before judging the request' do
    request = Rk::SponsorApp::AdminServiceListSponsorEventEditingHistoryRequest.new(conference_slug: conference.slug, sponsor_event_id: 0)

    expect(connect_call(rpc, request)).to have_attributes(status: 401, code: 'unauthenticated')
  end

  it 'answers permission_denied to restricted staff for a conference they may not manage' do
    sign_in_staff(restricted_staff)

    expect(connect_call(rpc, request_for(event))).to have_attributes(code: 'permission_denied')
  end
end
