# typed: strict
# frozen_string_literal: true

module Api
  class PassTicketResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::PassTicket do
      attributes :reference, :state, :void
      attributes :release_slug, if: proc { |ticket| ticket.release_slug }
      attributes :email, if: proc { |ticket| ticket.email }
    end
  end
end
