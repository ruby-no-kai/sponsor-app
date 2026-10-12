# typed: strict
# frozen_string_literal: true

module Api
  # Load sponsorships with their plan and organization, or each one queries them itself.
  class SponsorshipAttendeesResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::SponsorshipAttendees do
      one :sponsorship, source: proc { self }, resource: Api::SponsorshipSummaryResource
      attribute(:included_attendees) { |sponsorship| sponsorship.plan&.number_of_guests || 0 }
      attribute(:additional_attendees) { |sponsorship| sponsorship.number_of_additional_attendees || 0 }
      attribute(:total_attendees, &:total_number_of_attendees)
    end
  end
end
