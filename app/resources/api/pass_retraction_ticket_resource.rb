# typed: strict
# frozen_string_literal: true

module Api
  class PassRetractionTicketResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::PassRetraction::Ticket do
      attributes :reference
      attributes :release_slug, if: proc { |ticket| ticket.release_slug }
      attributes :email, if: proc { |ticket| ticket.email }
    end
  end
end
