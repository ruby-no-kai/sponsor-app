# typed: strict
# frozen_string_literal: true

module Api
  class ConferenceResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::Conference do
      attributes :slug, :name, :contact_email_address, :no_plan_allowed, :additional_attendees_registration_open

      # The :timestamp type cannot convert nil, so an unset time is left out.
      attributes application_opens_at: :timestamp, if: proc { |conference| conference.application_opens_at }
      attributes application_closes_at: :timestamp, if: proc { |conference| conference.application_closes_at }
      attributes amendment_closes_at: :timestamp, if: proc { |conference| conference.amendment_closes_at }
      attributes event_submission_starts_at: :timestamp, if: proc { |conference| conference.event_submission_starts_at }
      attributes ticket_distribution_starts_at: :timestamp, if: proc { |conference| conference.ticket_distribution_starts_at }
      attributes pass_retraction_disables_at: :timestamp, if: proc { |conference| conference.pass_retraction_disables_at }

      attribute(:booths_offered) { |conference| conference.booth_capacity > 0 }
    end
  end
end
