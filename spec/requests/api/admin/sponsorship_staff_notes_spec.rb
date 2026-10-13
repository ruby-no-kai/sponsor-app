# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AdminService sponsorship staff notes', type: :request do
  let(:staff) { FactoryBot.create(:staff, login: 'writer') }
  let(:restricted_staff) { FactoryBot.create(:staff, restricted_repos: ['ruby-no-kai/rubykaigi-admitted']) }
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first) }
  let(:other_conference) { FactoryBot.create(:conference, :full) }
  let(:elsewhere) { FactoryBot.create(:sponsorship, conference: other_conference, plan: other_conference.plans.first) }
  let(:author) { FactoryBot.create(:staff, login: 'author') }

  def note_input(body: 'Called the sponsor', pinned: false)
    Rk::SponsorApp::SponsorshipStaffNoteInput.new(body:, pinned:)
  end

  describe 'ListSponsorshipStaffNotes' do
    let(:rpc) { connect_method('AdminService', 'ListSponsorshipStaffNotes') }

    def request_for(sponsorship)
      Rk::SponsorApp::AdminServiceListSponsorshipStaffNotesRequest.new(conference_slug: conference.slug, sponsorship_id: sponsorship.id)
    end

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'lists every note, pinned ones first, each most recent first' do
        older = SponsorshipStaffNote.create!(sponsorship:, staff: author, body: 'Older', created_at: 2.days.ago)
        pinned = SponsorshipStaffNote.create!(sponsorship:, staff: author, body: 'Pinned', stickiness: 1, created_at: 3.days.ago)
        newer = SponsorshipStaffNote.create!(sponsorship:, staff: author, body: 'Newer *note*', created_at: 1.day.ago)
        SponsorshipStaffNote.create!(sponsorship: elsewhere, staff: author, body: 'Elsewhere')

        notes = connect_call(rpc, request_for(sponsorship)).staff_notes

        expect(notes.map(&:id)).to eq([pinned.id, newer.id, older.id])
        expect(notes[1]).to have_attributes(
          body: 'Newer *note*', pinned: false, staff_login: 'author',
          created_at: Google::Protobuf::Timestamp.from_time(newer.created_at.to_time),
        )
        expect(notes[1].body_html).to include('<em>note</em>')
      end

      it 'answers GET alike' do
        SponsorshipStaffNote.create!(sponsorship:, staff: author, body: 'Note')

        expect(connect_call(rpc, request_for(sponsorship), via: :get)).to eq(connect_call(rpc, request_for(sponsorship)))
      end

      it 'answers not_found for a sponsorship of another conference' do
        expect(connect_call(rpc, request_for(elsewhere))).to have_attributes(status: 404, code: 'not_found')
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

  describe 'CreateSponsorshipStaffNote' do
    let(:rpc) { connect_method('AdminService', 'CreateSponsorshipStaffNote') }

    def request_with(input, sponsorship_id: sponsorship.id)
      Rk::SponsorApp::AdminServiceCreateSponsorshipStaffNoteRequest.new(conference_slug: conference.slug, sponsorship_id:, input:)
    end

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'writes a note signed by the staff member' do
        result = connect_call(rpc, request_with(note_input(body: '# Called', pinned: true))).staff_note

        note = sponsorship.staff_notes.sole
        expect(note).to have_attributes(body: '# Called', stickiness: 1, staff:)
        expect(result).to have_attributes(id: note.id, pinned: true, staff_login: 'writer')
        expect(result.body_html).to include('<h1')
      end

      it 'answers invalid_argument for an empty body' do
        error = connect_call(rpc, request_with(note_input(body: '')))

        expect(violations_of(error)).to eq([['input.body', 'REQUIRED']])
        expect(sponsorship.staff_notes).to be_empty
      end

      it 'answers invalid_argument for a body of only whitespace' do
        error = connect_call(rpc, request_with(note_input(body: " \n ")))

        expect(violations_of(error)).to eq([['input.body', 'SPONSORSHIP_STAFF_NOTE_INPUT_BODY_NOT_BLANK']])
        expect(sponsorship.staff_notes).to be_empty
      end

      it 'answers not_found for a sponsorship of another conference' do
        expect(connect_call(rpc, request_with(note_input, sponsorship_id: elsewhere.id))).to have_attributes(code: 'not_found')
        expect(elsewhere.staff_notes).to be_empty
      end
    end

    it 'answers unauthenticated before judging the request' do
      expect(connect_call(rpc, request_with(note_input(body: '')))).to have_attributes(code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_with(note_input))).to have_attributes(code: 'permission_denied')
      expect(sponsorship.staff_notes).to be_empty
    end
  end

  describe 'UpdateSponsorshipStaffNote' do
    let(:rpc) { connect_method('AdminService', 'UpdateSponsorshipStaffNote') }
    let!(:note) { SponsorshipStaffNote.create!(sponsorship:, staff: author, body: 'Old body') }

    def request_with(input, staff_note_id: note.id, sponsorship_id: sponsorship.id)
      Rk::SponsorApp::AdminServiceUpdateSponsorshipStaffNoteRequest.new(
        conference_slug: conference.slug, sponsorship_id:, staff_note_id:, input:,
      )
    end

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it "replaces the body and pinning of another staff member's note, which keeps its author" do
        result = connect_call(rpc, request_with(note_input(body: 'New body', pinned: true))).staff_note

        expect(note.reload).to have_attributes(body: 'New body', stickiness: 1, staff: author)
        expect(result).to have_attributes(body: 'New body', pinned: true, staff_login: 'author')

        connect_call(rpc, request_with(note_input(body: 'New body', pinned: false)))
        expect(note.reload.stickiness).to eq(0)
      end

      it 'answers invalid_argument for a body of only whitespace, keeping the note' do
        error = connect_call(rpc, request_with(note_input(body: '   ')))

        expect(violations_of(error)).to eq([['input.body', 'SPONSORSHIP_STAFF_NOTE_INPUT_BODY_NOT_BLANK']])
        expect(note.reload.body).to eq('Old body')
      end

      it 'keeps the stickiness of a note pinned above others' do
        note.update!(stickiness: 3)

        connect_call(rpc, request_with(note_input(pinned: true)))

        expect(note.reload.stickiness).to eq(3)
      end

      it 'answers not_found for a note on another sponsorship of the conference' do
        sibling = FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first)

        error = connect_call(rpc, request_with(note_input(body: 'New body'), sponsorship_id: sibling.id))

        expect(error).to have_attributes(code: 'not_found')
        expect(note.reload.body).to eq('Old body')
      end

      it 'answers not_found for a note of another conference' do
        foreign = SponsorshipStaffNote.create!(sponsorship: elsewhere, staff: author, body: 'Foreign')

        expect(connect_call(rpc, request_with(note_input(body: 'New body'), staff_note_id: foreign.id))).to have_attributes(code: 'not_found')
        expect(connect_call(rpc, request_with(note_input(body: 'New body'), staff_note_id: foreign.id, sponsorship_id: elsewhere.id)))
          .to have_attributes(code: 'not_found')
        expect(foreign.reload.body).to eq('Foreign')
      end
    end

    it 'answers unauthenticated without a staff session' do
      expect(connect_call(rpc, request_with(note_input(body: 'New body')))).to have_attributes(status: 401, code: 'unauthenticated')
      expect(note.reload.body).to eq('Old body')
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_with(note_input(body: 'New body')))).to have_attributes(code: 'permission_denied')
      expect(note.reload.body).to eq('Old body')
    end
  end

  describe 'DeleteSponsorshipStaffNote' do
    let(:rpc) { connect_method('AdminService', 'DeleteSponsorshipStaffNote') }
    let!(:note) { SponsorshipStaffNote.create!(sponsorship:, staff: author, body: 'Old body') }

    def request_for(staff_note_id: note.id, sponsorship_id: sponsorship.id)
      Rk::SponsorApp::AdminServiceDeleteSponsorshipStaffNoteRequest.new(conference_slug: conference.slug, sponsorship_id:, staff_note_id:)
    end

    context 'with a staff session' do
      before { sign_in_staff(staff) }

      it 'deletes the note' do
        expect(connect_call(rpc, request_for)).to eq(Rk::SponsorApp::AdminServiceDeleteSponsorshipStaffNoteResponse.new)
        expect(SponsorshipStaffNote).not_to exist(note.id)
      end

      it 'answers not_found for a note of another conference' do
        foreign = SponsorshipStaffNote.create!(sponsorship: elsewhere, staff: author, body: 'Foreign')

        expect(connect_call(rpc, request_for(staff_note_id: foreign.id))).to have_attributes(code: 'not_found')
        expect(SponsorshipStaffNote).to exist(foreign.id)
      end

      it 'refuses GET, as deleting has side effects' do
        get "#{rpc.path}?#{URI.encode_www_form(connect: 'v1', encoding: 'json', message: request_for.to_json)}"

        expect(response).to have_http_status(:method_not_allowed)
        expect(SponsorshipStaffNote).to exist(note.id)
      end
    end

    it 'answers unauthenticated without a staff session' do
      expect(connect_call(rpc, request_for)).to have_attributes(status: 401, code: 'unauthenticated')
      expect(SponsorshipStaffNote).to exist(note.id)
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_for)).to have_attributes(code: 'permission_denied')
      expect(SponsorshipStaffNote).to exist(note.id)
    end
  end
end
