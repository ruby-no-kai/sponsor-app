# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Admin Sponsorship Staff Notes", type: :request do
  let(:conference) { FactoryBot.create(:conference, :full) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan: conference.plans.first) }
  let(:staff) { FactoryBot.create(:staff) }
  let(:session_token) { FactoryBot.create(:session_token, staff:) }

  before do
    get claim_user_session_path(session_token.handle)
  end

  describe "GET index" do
    it "lists the notes of the sponsorship" do
      SponsorshipStaffNote.create!(sponsorship:, staff:, body: 'Called the sponsor')

      get conference_sponsorship_staff_notes_path(conference, sponsorship)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Called the sponsor')
    end
  end

  describe "POST create" do
    it "adds a note by the current staff" do
      expect do
        post conference_sponsorship_staff_notes_path(conference, sponsorship), params: {sponsorship_staff_note: {body: 'New note', stickiness: 0}}
      end.to change(sponsorship.staff_notes, :count).by(1)

      expect(sponsorship.staff_notes.last.staff).to eq(staff)
      expect(response).to redirect_to(conference_sponsorship_staff_notes_path(conference, sponsorship))
    end
  end

  describe "existing note" do
    let!(:note) { SponsorshipStaffNote.create!(sponsorship:, staff:, body: 'Old body') }

    it "renders the edit form" do
      get edit_conference_sponsorship_staff_note_path(conference, sponsorship, note)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Old body')
    end

    it "updates the note" do
      patch conference_sponsorship_staff_note_path(conference, sponsorship, note), params: {sponsorship_staff_note: {body: 'New body'}, back_to: 'sponsorship'}

      expect(response).to redirect_to(conference_sponsorship_path(conference, sponsorship))
      expect(note.reload.body).to eq('New body')
    end

    it "destroys the note" do
      expect do
        delete conference_sponsorship_staff_note_path(conference, sponsorship, note)
      end.to change(SponsorshipStaffNote, :count).by(-1)

      expect(response).to redirect_to(conference_sponsorship_staff_notes_path(conference, sponsorship))
    end
  end

  context "with a sponsorship of another conference" do
    let(:staff) { FactoryBot.create(:staff, restricted_repos: ['org/allowed']) }
    let(:conference) { FactoryBot.create(:conference, :full, allow_restricted_access: true, github_repo: 'org/allowed@main:data') }
    let(:other_conference) { FactoryBot.create(:conference, :full) }
    let(:other_sponsorship) { FactoryBot.create(:sponsorship, conference: other_conference, plan: other_conference.plans.first) }
    let!(:other_note) { SponsorshipStaffNote.create!(sponsorship: other_sponsorship, staff:, body: 'Confidential') }

    it "does not list its notes" do
      get conference_sponsorship_staff_notes_path(conference, other_sponsorship)

      expect(response).to have_http_status(:not_found)
    end

    it "does not add a note to it" do
      expect do
        post conference_sponsorship_staff_notes_path(conference, other_sponsorship), params: {sponsorship_staff_note: {body: 'Injected', stickiness: 0}}
      end.not_to change(SponsorshipStaffNote, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "does not update its notes" do
      patch conference_sponsorship_staff_note_path(conference, sponsorship, other_note), params: {sponsorship_staff_note: {body: 'Tampered'}}

      expect(response).to have_http_status(:not_found)
      expect(other_note.reload.body).to eq('Confidential')
    end
  end
end
