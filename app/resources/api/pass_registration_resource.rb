# typed: strict
# frozen_string_literal: true

module Api
  # Takes the PassRedemption::Collection it was listed in as params[:collection].
  class PassRegistrationResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::PassRegistration do
      attribute(:id) { |registration| registration.id.to_s }
      attributes :reference
      attributes :email, if: proc { |registration| registration.email }
      attribute(:retractable) do |registration|
        collection = params.fetch(:collection) #: PassRedemption::Collection
        collection.retractable?(registration) && !collection.holds_other_codes?(registration)
      end
      attribute(:tickets) do |registration|
        collection = params.fetch(:collection) #: PassRedemption::Collection
        collection.tickets_for(registration).map { Api::PassTicketResource.new(it).as_protobuf }
      end
    end
  end
end
