# typed: strict
# frozen_string_literal: true

module Api
  # Load notes with their staff, or each one loads its own.
  class SponsorshipStaffNoteResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::SponsorshipStaffNote do
      attributes :id, :body
      attributes created_at: :timestamp, updated_at: :timestamp
      attribute(:body_html) { |staff_note| staff_note.html.to_str }
      attribute(:pinned, &:pin?)
      attribute(:staff_login) { |staff_note| Must.expect(staff_note.staff).login }
    end
  end
end
