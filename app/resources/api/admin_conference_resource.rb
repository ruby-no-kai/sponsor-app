# typed: strict
# frozen_string_literal: true

module Api
  # Takes the application form URL in `params[:application_form_url]`, as it is built from the
  # request's host.
  class AdminConferenceResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::AdminConference do
      one :conference, source: proc { self }, resource: Api::ConferenceResource
      attributes :hidden, :allow_restricted_access, :booth_capacity
      attribute(:application_form_url) { params.fetch(:application_form_url) }
    end
  end
end
