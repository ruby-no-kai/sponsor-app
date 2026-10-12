# typed: strict
# frozen_string_literal: true

module Api
  class AdminSponsorshipContactResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::AdminSponsorship::Contact do
      attributes :email, :address, :organization, :name
      attributes :email_cc, if: proc { |contact| contact.email_cc.present? }
      attributes :unit, if: proc { |contact| contact.unit.present? }

      # The same compose URL the staff area's HAML pages link to.
      attribute(:compose_email_url) do |contact|
        conference = Must.expect(Must.expect(contact.sponsorship).conference)
        ::ApplicationController.helpers.front_mail_to_link(contact.email, from: conference.contact_email_address, cc: contact.email_ccs)
      end
    end
  end
end
