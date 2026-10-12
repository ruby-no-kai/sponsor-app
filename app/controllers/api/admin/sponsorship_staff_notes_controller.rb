# typed: strict
# frozen_string_literal: true

module Api
  module Admin
    # Any staff member who may manage the conference may change or delete any note on it.
    class SponsorshipStaffNotesController < Api::Admin::ApplicationController
      include Api::Admin::SponsorshipLookup

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceListSponsorshipStaffNotesResponse
      def list_sponsorship_staff_notes
        staff_notes = find_sponsorship.staff_notes.includes(:staff).order(stickiness: :desc, created_at: :desc)

        Rk::SponsorApp::AdminServiceListSponsorshipStaffNotesResponse.new(
          staff_notes: staff_notes.map { staff_note_message(it) },
        )
      end

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceCreateSponsorshipStaffNoteResponse
      def create_sponsorship_staff_note
        input = connect_request.input #: Rk::SponsorApp::SponsorshipStaffNoteInput
        staff_note = find_sponsorship.staff_notes.build(staff: current_staff)
        save_input!(staff_note, input)

        Rk::SponsorApp::AdminServiceCreateSponsorshipStaffNoteResponse.new(staff_note: staff_note_message(staff_note))
      end

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceUpdateSponsorshipStaffNoteResponse
      def update_sponsorship_staff_note
        input = connect_request.input #: Rk::SponsorApp::SponsorshipStaffNoteInput
        staff_note = find_staff_note
        save_input!(staff_note, input)

        Rk::SponsorApp::AdminServiceUpdateSponsorshipStaffNoteResponse.new(staff_note: staff_note_message(staff_note))
      end

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceDeleteSponsorshipStaffNoteResponse
      def delete_sponsorship_staff_note
        find_staff_note.destroy!

        Rk::SponsorApp::AdminServiceDeleteSponsorshipStaffNoteResponse.new
      end

      # A note on another sponsorship is not found, even one of the same conference.
      #: () -> SponsorshipStaffNote
      private def find_staff_note
        id = connect_request.staff_note_id #: Integer
        sponsorship = find_sponsorship
        sponsorship.staff_notes.find_by(id:) || raise(Errors::NotFound.new(
          detail: "The sponsorship #{sponsorship.id} has no staff note #{id}.",
        ))
      end

      # A note keeps a stickiness above one, which orders it among the pinned ones.
      #: (SponsorshipStaffNote, Rk::SponsorApp::SponsorshipStaffNoteInput) -> void
      private def save_input!(staff_note, input)
        staff_note.body = input.body
        staff_note.stickiness = input.pinned ? [staff_note.stickiness, 1].max : 0
        staff_note.save!
      end

      #: (SponsorshipStaffNote) -> Rk::SponsorApp::SponsorshipStaffNote
      private def staff_note_message(staff_note)
        Api::SponsorshipStaffNoteResource.new(staff_note).as_protobuf
      end
    end
  end
end
