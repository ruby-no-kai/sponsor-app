# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AdminService sponsorship editing history', type: :request do
  let(:staff) { FactoryBot.create(:staff, login: 'editor') }
  let(:restricted_staff) { FactoryBot.create(:staff, restricted_repos: ['ruby-no-kai/rubykaigi-admitted']) }
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first, name: 'Before') }
  let(:rpc) { connect_method('AdminService', 'ListSponsorshipEditingHistory') }

  def request_for(sponsorship)
    Rk::SponsorApp::AdminServiceListSponsorshipEditingHistoryRequest.new(conference_slug: conference.slug, sponsorship_id: sponsorship.id)
  end

  def value(ruby)
    Google::Protobuf::Value.from_ruby(ruby)
  end

  context 'with a staff session' do
    before { sign_in_staff(staff) }

    it 'lists the saves newest first, with the staff member and the old and new values' do
      created = sponsorship.editing_histories.sole
      sponsorship.update!(name: 'After', number_of_additional_attendees: 2, staff:)
      sponsorship.staff = nil
      sponsorship.contact.email_cc = 'cc@example.invalid'
      sponsorship.update!(suspended: true)

      entries = connect_call(rpc, request_for(sponsorship)).entries.to_a

      expect(entries.map(&:has_staff_login?)).to eq([false, true, false])
      expect(entries.second.staff_login).to eq('editor')
      expect(entries.last).to have_attributes(id: created.id, created_at: Google::Protobuf::Timestamp.from_time(created.created_at.to_time))

      edit = entries.second.changes.index_by(&:path)
      expect(edit.fetch('name')).to have_attributes(operation: :OPERATION_CHANGED, old_value: value('Before'), new_value: value('After'))
      expect(edit.fetch('number_of_additional_attendees')).to have_attributes(old_value: value(nil), new_value: value(2))
      expect(entries.first.changes.map { [it.operation, it.path] }).to contain_exactly(
        [:OPERATION_CHANGED, 'contact.email_cc'], [:OPERATION_CHANGED, 'suspended?'],
      )
    end

    it 'gives an added path no old value and a removed path no new value' do
      sponsorship.withdraw.save!
      sponsorship.update!(withdrawn_at: nil)

      entries = connect_call(rpc, request_for(sponsorship)).entries.to_a
      removed = entries.first.changes.find { it.path == 'withdrawn_at' }
      added = entries.second.changes.find { it.path == 'withdrawn_at' }

      expect(added).to have_attributes(operation: :OPERATION_ADDED, has_old_value?: false, has_new_value?: true)
      expect(removed).to have_attributes(operation: :OPERATION_REMOVED, has_old_value?: true, has_new_value?: false)
      expect(removed.old_value).to eq(added.new_value)
    end

    it 'keeps an object whole when the first save adds it' do
      contact = connect_call(rpc, request_for(sponsorship)).entries.sole.changes.find { it.path == 'contact' }

      expect(contact.operation).to eq(:OPERATION_ADDED)
      expect(contact.new_value.struct_value.to_h).to include('email' => sponsorship.contact.email, 'unit' => nil)
    end

    it 'answers GET, in JSON and binary, and binary POST alike' do
      sponsorship.update!(name: 'After', staff:)
      expected = connect_call(rpc, request_for(sponsorship))

      expect(connect_call(rpc, request_for(sponsorship), via: :get)).to eq(expected)
      expect(connect_call(rpc, request_for(sponsorship), via: :get, codec: :proto)).to eq(expected)
      expect(connect_call(rpc, request_for(sponsorship), codec: :proto)).to eq(expected)
    end

    it 'answers not_found for a sponsorship of another conference' do
      other_conference = FactoryBot.create(:conference, :full)
      elsewhere = FactoryBot.create(:sponsorship, conference: other_conference, plan: other_conference.plans.first)

      expect(connect_call(rpc, request_for(elsewhere))).to have_attributes(status: 404, code: 'not_found')
    end

    it 'answers invalid_argument for a sponsorship ID that cannot exist' do
      error = connect_call(rpc, Rk::SponsorApp::AdminServiceListSponsorshipEditingHistoryRequest.new(conference_slug: conference.slug, sponsorship_id: 0))

      expect(error).to have_attributes(status: 400, code: 'invalid_argument')
      expect(violations_of(error)).to eq([['sponsorshipId', 'INT64_GT']])
    end
  end

  it 'answers unauthenticated without a staff session' do
    expect(connect_call(rpc, request_for(sponsorship))).to have_attributes(code: 'unauthenticated')
  end

  it 'answers permission_denied to restricted staff for a conference they may not manage' do
    sign_in_staff(restricted_staff)

    expect(connect_call(rpc, request_for(sponsorship))).to have_attributes(code: 'permission_denied')
  end
end
