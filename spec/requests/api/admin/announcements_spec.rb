# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AdminService announcements', type: :request do
  let(:staff) { FactoryBot.create(:staff) }
  let(:author) { FactoryBot.create(:staff) }
  let(:restricted_staff) { FactoryBot.create(:staff, restricted_repos: ['ruby-no-kai/rubykaigi-admitted']) }
  let(:conference) { FactoryBot.create(:conference) }
  let(:other_conference) { FactoryBot.create(:conference) }
  let(:published_at) { Time.zone.parse('2026-05-01 10:00:00') }

  def announce(issue:, locale: 'en', **attributes)
    FactoryBot.create(:announcement, conference:, staff: author, issue:, locale:, **attributes)
  end

  def input(**fields)
    Rk::SponsorApp::AnnouncementInput.new(
      locale: 'en',
      title: 'Booth setup',
      body: '**Doors** open at 8:00.',
      pinned: false,
      exhibitors_only: false,
      published: false,
      new_revision: false,
      **fields,
    )
  end

  def summary(locale:, title:, revision: 1, behind: false, **flags)
    Rk::SponsorApp::AdminAnnouncementSummary.new(locale:, title:, revision:, behind:, published: false, pinned: false,
      exhibitors_only: false, **flags)
  end

  describe 'ListAnnouncements' do
    let(:rpc) { connect_method('AdminService', 'ListAnnouncements') }

    def request_for(slug = conference.slug) = Rk::SponsorApp::AdminServiceListAnnouncementsRequest.new(conference_slug: slug)

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'lists issues pinned first, then newest first, each with its locales in locale order' do
        announce(issue: 'oldest', title: 'Oldest')
        announce(issue: 'pinned', locale: 'ja', title: 'Pinned JA')
        announce(issue: 'pinned', title: 'Pinned EN', stickiness: 1, published_at:)
        announce(issue: 'newest', locale: 'ja', title: 'Newest JA')
        announce(issue: 'newest', title: 'Newest EN', revision: 2, exhibitors_only: true)
        FactoryBot.create(:announcement, conference: other_conference, issue: 'elsewhere')

        issues = connect_call(rpc, request_for).issues

        expect(issues.map(&:issue)).to eq(['pinned', 'newest', 'oldest'])
        expect(issues[0].announcements.to_a).to eq([
          summary(locale: 'en', title: 'Pinned EN', published: true, pinned: true),
          summary(locale: 'ja', title: 'Pinned JA'),
        ])
        expect(issues[1].announcements.to_a).to eq([
          summary(locale: 'en', title: 'Newest EN', revision: 2, exhibitors_only: true),
          summary(locale: 'ja', title: 'Newest JA', revision: 1, behind: true),
        ])
      end

      it 'answers GET, in JSON and binary, and binary POST alike' do
        announce(issue: 'one', title: 'One')
        expected = connect_call(rpc, request_for)

        expect(connect_call(rpc, request_for, via: :get)).to eq(expected)
        expect(connect_call(rpc, request_for, via: :get, codec: :proto)).to eq(expected)
        expect(connect_call(rpc, request_for, codec: :proto)).to eq(expected)
      end

      it 'lists in as many queries however many issues there are' do
        announce(issue: 'one', title: 'One')
        baseline = query_count { connect_call(rpc, request_for) }
        announce(issue: 'one', locale: 'ja', title: 'One JA')
        announce(issue: 'two', title: 'Two')

        expect(query_count { connect_call(rpc, request_for) }).to eq(baseline)
      end

      it 'returns no issues for a conference without announcements' do
        expect(connect_call(rpc, request_for).issues).to be_empty
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

  describe 'GetAnnouncement' do
    let(:rpc) { connect_method('AdminService', 'GetAnnouncement') }

    def request_for(issue, locale, slug: conference.slug)
      Rk::SponsorApp::AdminServiceGetAnnouncementRequest.new(conference_slug: slug, issue:, locale:)
    end

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'returns every field with the rendered body, the sponsor page link and the locales of the issue' do
        announce(issue: 'setup', locale: 'ja', title: 'Setup JA')
        announce(issue: 'setup', title: 'Setup', body: 'Doors open at *8:00*.', revision: 2, stickiness: 1, exhibitors_only: true,
          published_at:)
        announce(issue: 'other', title: 'Other')

        response = connect_call(rpc, request_for('setup', 'en'))

        expect(response.announcement).to have_attributes(
          issue: 'setup',
          locale: 'en',
          title: 'Setup',
          body: 'Doors open at *8:00*.',
          published: true,
          published_at: Google::Protobuf::Timestamp.from_time(published_at),
          pinned: true,
          exhibitors_only: true,
          revision: 2,
          sponsor_page_url: "http://www.example.com/conferences/#{conference.slug}/sponsorship#announcement-setup",
        )
        expect(response.announcement.body_html).to include('<em>8:00</em>')
        expect(response.issue.issue).to eq('setup')
        expect(response.issue.announcements.to_a).to eq([
          summary(locale: 'en', title: 'Setup', revision: 2, published: true, pinned: true, exhibitors_only: true),
          summary(locale: 'ja', title: 'Setup JA', behind: true),
        ])
      end

      it 'returns a draft without a publication time' do
        announce(issue: 'draft', title: 'Draft')

        expect(connect_call(rpc, request_for('draft', 'en')).announcement).to have_attributes(published: false, published_at: nil)
      end

      it 'answers GET, in JSON and binary, and binary POST alike' do
        announce(issue: 'setup', title: 'Setup')
        expected = connect_call(rpc, request_for('setup', 'en'))

        expect(connect_call(rpc, request_for('setup', 'en'), via: :get)).to eq(expected)
        expect(connect_call(rpc, request_for('setup', 'en'), via: :get, codec: :proto)).to eq(expected)
        expect(connect_call(rpc, request_for('setup', 'en'), codec: :proto)).to eq(expected)
      end

      it 'answers not_found for an issue of another conference' do
        FactoryBot.create(:announcement, conference: other_conference, issue: 'elsewhere', locale: 'en')

        error = connect_call(rpc, request_for('elsewhere', 'en'))

        expect(error).to have_attributes(status: 404, code: 'not_found')
        expect(problem_type_of(error)).to eq('not-found')
      end

      it "answers not_found when the slug names a conference other than the announcement's" do
        announce(issue: 'setup', title: 'Setup')

        expect(connect_call(rpc, request_for('setup', 'en', slug: other_conference.slug))).to have_attributes(code: 'not_found')
      end

      it 'answers not_found for a locale the issue is not written in' do
        announce(issue: 'setup', title: 'Setup')

        expect(connect_call(rpc, request_for('setup', 'ja'))).to have_attributes(code: 'not_found')
      end

      it 'answers invalid_argument for an empty issue or locale' do
        expect(violations_of(connect_call(rpc, request_for('', '')))).to contain_exactly(
          ['issue', 'STRING_MIN_LEN'],
          ['locale', 'STRING_MIN_LEN'],
        )
      end
    end

    it 'answers unauthenticated without a staff session, before judging the request' do
      expect(connect_call(rpc, request_for('', ''))).to have_attributes(code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      announce(issue: 'setup', title: 'Setup')
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_for('setup', 'en'))).to have_attributes(code: 'permission_denied')
    end
  end

  describe 'CreateAnnouncement' do
    let(:rpc) { connect_method('AdminService', 'CreateAnnouncement') }

    def request_with(input, issue: nil, slug: conference.slug)
      Rk::SponsorApp::AdminServiceCreateAnnouncementRequest.new(conference_slug: slug, issue:, input:)
    end

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'starts an issue under a generated identifier, written by the staff member' do
        created = connect_call(rpc, request_with(input(pinned: true, exhibitors_only: true, published: true))).announcement

        stored = conference.announcements.sole
        expect(stored).to have_attributes(
          issue: match(/\A[A-Za-z0-9_-]{11}\z/),
          locale: 'en',
          title: 'Booth setup',
          body: '**Doors** open at 8:00.',
          stickiness: 1,
          exhibitors_only: true,
          published_at: be_present,
          revision: 1,
          staff:,
        )
        expect(created).to have_attributes(issue: stored.issue, pinned: true, published: true, revision: 1)
        expect(created.body_html).to include('<strong>Doors</strong>')
        expect(created.sponsor_page_url).to end_with("/sponsorship#announcement-#{stored.issue}")
      end

      it 'stores a draft without a publication time' do
        connect_call(rpc, request_with(input))

        expect(conference.announcements.sole).to have_attributes(published_at: nil, stickiness: 0, exhibitors_only: false)
      end

      it "adds a locale to an existing issue at the issue's latest revision" do
        announce(issue: 'setup', title: 'Setup', revision: 3)

        created = connect_call(rpc, request_with(input(locale: 'ja', title: 'Setup JA'), issue: 'setup')).announcement

        expect(created).to have_attributes(issue: 'setup', locale: 'ja', revision: 3)
        expect(conference.announcements.where(issue: 'setup').pluck(:locale, :revision)).to contain_exactly(['en', 3], ['ja', 3])
      end

      it "asks the issue's other locales for a translation with new_revision" do
        announce(issue: 'setup', title: 'Setup')

        connect_call(rpc, request_with(input(locale: 'ja', title: 'Setup JA', new_revision: true), issue: 'setup'))

        expect(conference.announcements.find_by!(issue: 'setup', locale: 'ja').revision).to eq(2)
        expect(conference.announcements.find_by!(issue: 'setup', locale: 'en').revision_behind?).to be(true)
      end

      it 'creates over binary protobuf too' do
        expect(connect_call(rpc, request_with(input), codec: :proto).announcement.title).to eq('Booth setup')
      end

      it 'answers not_found for an issue of another conference, creating nothing' do
        FactoryBot.create(:announcement, conference: other_conference, issue: 'elsewhere', locale: 'en')

        error = connect_call(rpc, request_with(input(locale: 'ja'), issue: 'elsewhere'))

        expect(error).to have_attributes(status: 404, code: 'not_found')
        expect(conference.announcements).to be_empty
      end

      it 'answers aborted with the conflict problem for a locale the issue is already written in' do
        announce(issue: 'setup', title: 'Setup')

        error = connect_call(rpc, request_with(input, issue: 'setup'))

        expect(error).to have_attributes(status: 409, code: 'aborted')
        expect(problem_type_of(error)).to eq('conflict')
        expect(conference.announcements.count).to eq(1)
      end

      it 'answers invalid_argument with a violation per broken rule, creating nothing' do
        error = connect_call(rpc, request_with(input(locale: 'fr', title: ' ', body: 'x' * 65_537), issue: ''))

        expect(error).to have_attributes(status: 400, code: 'invalid_argument')
        expect(violations_of(error)).to contain_exactly(
          ['issue', 'STRING_MIN_LEN'],
          ['input.locale', 'STRING_IN'],
          ['input.title', 'ANNOUNCEMENT_INPUT_TITLE_NOT_BLANK'],
          ['input.body', 'STRING_MAX_LEN'],
        )
        expect(conference.announcements).to be_empty
      end

      it 'answers invalid_argument for an empty locale as a missing one' do
        expect(violations_of(connect_call(rpc, request_with(input(locale: ''))))).to eq([['input.locale', 'REQUIRED']])
      end

      it 'answers the invalid-record problem on the body field for a blank body' do
        error = connect_call(rpc, request_with(input(body: ' ')))

        expect(error).to have_attributes(status: 400, code: 'invalid_argument')
        expect(error.detail(Protobufable::ProblemDetails)).to have_attributes(
          type: 'https://sponsorships.rubykaigi.org/problems/invalid-record',
          status: 422,
        )
        expect(violations_of(error)).to eq([['input.body', 'BLANK']])
        expect(conference.announcements).to be_empty
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
      expect(connect_call(rpc, request_with(input(title: '')))).to have_attributes(code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_with(input))).to have_attributes(code: 'permission_denied')
      expect(conference.announcements).to be_empty
    end
  end

  describe 'UpdateAnnouncement' do
    let(:rpc) { connect_method('AdminService', 'UpdateAnnouncement') }
    let!(:announcement) { announce(issue: 'setup', title: 'Setup', body: 'Before', published_at:) }

    def request_with(input, issue: 'setup', locale: 'en', slug: conference.slug)
      Rk::SponsorApp::AdminServiceUpdateAnnouncementRequest.new(conference_slug: slug, issue:, locale:, input:)
    end

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'replaces every field, keeping the issue and the author' do
        updated = connect_call(rpc, request_with(input(title: 'Changed', body: 'After', pinned: true, exhibitors_only: true))).announcement

        expect(announcement.reload).to have_attributes(
          issue: 'setup',
          locale: 'en',
          title: 'Changed',
          body: 'After',
          stickiness: 1,
          exhibitors_only: true,
          published_at: nil,
          staff: author,
        )
        expect(updated).to have_attributes(issue: 'setup', title: 'Changed', pinned: true, published: false)
      end

      it 'keeps the publication time of an announcement published again' do
        connect_call(rpc, request_with(input(published: true)))

        expect(announcement.reload.published_at).to eq(published_at)
      end

      it 'keeps the stickiness of an announcement pinned again' do
        announcement.update!(stickiness: 10)

        connect_call(rpc, request_with(input(pinned: true)))

        expect(announcement.reload.stickiness).to eq(10)
      end

      it "brings a locale behind the issue up to the issue's latest revision without new_revision" do
        announce(issue: 'setup', locale: 'ja', title: 'Setup JA', revision: 2)

        expect(connect_call(rpc, request_with(input)).announcement.revision).to eq(2)
        expect(announcement.reload.revision_behind?).to be(false)
      end

      it "raises the revision with new_revision, leaving the issue's other locales behind" do
        ja = announce(issue: 'setup', locale: 'ja', title: 'Setup JA')

        expect(connect_call(rpc, request_with(input(new_revision: true))).announcement.revision).to eq(2)
        expect(ja.reload.revision_behind?).to be(true)
      end

      it 'moves the announcement to a locale its issue is not written in' do
        connect_call(rpc, request_with(input(locale: 'ja')))

        expect(announcement.reload).to have_attributes(issue: 'setup', locale: 'ja')
      end

      it 'answers aborted when moving onto a locale the issue is already written in, leaving it as it was' do
        announce(issue: 'setup', locale: 'ja', title: 'Setup JA')

        expect(connect_call(rpc, request_with(input(locale: 'ja', title: 'Changed')))).to have_attributes(code: 'aborted')
        expect(announcement.reload).to have_attributes(locale: 'en', title: 'Setup')
      end

      it 'answers not_found for an issue of another conference, leaving it as it was' do
        elsewhere = FactoryBot.create(:announcement, conference: other_conference, issue: 'elsewhere', locale: 'en', title: 'Elsewhere')

        expect(connect_call(rpc, request_with(input, issue: 'elsewhere'))).to have_attributes(code: 'not_found')
        expect(elsewhere.reload.title).to eq('Elsewhere')
      end

      it 'answers the invalid-record problem for a blank body, leaving it as it was' do
        error = connect_call(rpc, request_with(input(title: 'Changed', body: '')))

        expect(problem_type_of(error)).to eq('invalid-record')
        expect(violations_of(error)).to eq([['input.body', 'BLANK']])
        expect(announcement.reload.title).to eq('Setup')
      end

      it 'updates over binary protobuf too' do
        expect(connect_call(rpc, request_with(input(title: 'Changed')), codec: :proto).announcement.title).to eq('Changed')
      end
    end

    it 'answers unauthenticated without a staff session, before judging the request' do
      expect(connect_call(rpc, request_with(input(title: '')))).to have_attributes(code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_with(input(title: 'Changed')))).to have_attributes(code: 'permission_denied')
      expect(announcement.reload.title).to eq('Setup')
    end
  end
end
