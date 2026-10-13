# typed: strict
# frozen_string_literal: true

module Api
  # Binds a conference, and takes the organization the URL files applications under in
  # `params[:organization]`.
  class OrganizationAffiliationUrlResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::OrganizationAffiliationUrl do
      one :conference, source: proc { self }, resource: Api::ConferenceResource
      attribute(:url) { |conference| params.fetch(:organization).affiliation_url(conference) }
    end
  end
end
