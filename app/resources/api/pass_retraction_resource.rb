# typed: strict
# frozen_string_literal: true

module Api
  # Publishes a TitoTicketRetraction, saved or only prepared from the registration Tito holds now.
  class PassRetractionResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::PassRetraction do
      attributes :tito_registration_id
      attribute(:state) do |retraction|
        if retraction.new_record?
          :STATE_NOT_REQUESTED
        elsif retraction.completed?
          :STATE_COMPLETED
        else
          :STATE_PENDING
        end
      end
      attribute(:reference) { |retraction| Must.because(retraction.order_reference) { 'a retraction holds its registration' } }
      attribute(:email, if: proc { |retraction| retraction.registration_email }, &:registration_email)
      many :affected_tickets, key: :tickets, resource: Api::PassRetractionTicketResource
      attribute(:retractable, &:retractable?)
      attributes :reason, if: proc { |retraction| retraction.persisted? }
    end
  end
end
