# typed: strict
# frozen_string_literal: true

module Api
  # Copies what the staff's and the sponsor's sponsorship Inputs share onto a sponsorship's own
  # records. A record is never looked up by an ID from the request, so a request can reach only the
  # sponsorship it names.
  module SponsorshipInputAssignable
    include Kernel

    #: type input = Rk::SponsorApp::AdminSponsorshipInput | Rk::SponsorApp::SponsorshipInput
    #: type contact_input = Rk::SponsorApp::AdminSponsorshipInput::Contact | Rk::SponsorApp::SponsorshipInput::Contact
    #: type billing_contact_input = Rk::SponsorApp::AdminSponsorshipInput::BillingContact | Rk::SponsorApp::SponsorshipInput::BillingContact

    # The HAML forms store a blank optional string as "", so an absent one leaves a blank value as it is.
    #: (String?, String?) -> String?
    private def optional_string(given, stored)
      given || (stored if stored.blank?)
    end

    # The plan the Input names, or nil for none. One of another conference is not found.
    #: (Conference, input) -> Plan?
    private def input_plan(conference, input)
      return unless input.has_plan_id?

      plan_id = input.plan_id
      conference.plans.find_by(id: plan_id) || raise(Errors::NotFound.new(
        detail: "The conference #{conference.slug.inspect} has no plan #{plan_id}.",
      ))
    end

    #: (Sponsorship, contact_input) -> void
    private def assign_contact(sponsorship, contact)
      stored = sponsorship.contact || sponsorship.build_contact
      stored.assign_attributes(
        email: contact.email,
        email_cc: optional_string((contact.email_cc if contact.has_email_cc?), stored.email_cc),
        address: contact.address,
        organization: contact.organization,
        unit: optional_string((contact.unit if contact.has_unit?), stored.unit),
        name: contact.name,
      )
    end

    # Absent removes the billing contact stored, leaving invoices to the contact.
    #: (Sponsorship, billing_contact_input?) -> void
    private def assign_alternate_billing_contact(sponsorship, billing_contact)
      unless billing_contact
        sponsorship.alternate_billing_contact&.mark_for_destruction
        return
      end

      stored = sponsorship.alternate_billing_contact || sponsorship.build_alternate_billing_contact
      stored.assign_attributes(
        email: billing_contact.email,
        address: billing_contact.address,
        organization: billing_contact.organization,
        unit: optional_string((billing_contact.unit if billing_contact.has_unit?), stored.unit),
        name: billing_contact.name,
      )
    end

    #: (Sponsorship, input) -> void
    private def assign_requests(sponsorship, input)
      assign_request(sponsorship.customization_request, input.customization_request) { sponsorship.build_customization_request }
      assign_request(sponsorship.billing_request, input.billing_request) { sponsorship.build_billing_request }
      assign_request(sponsorship.note, input.note) { sponsorship.build_note }
    end

    # A blank body removes the request, as the sponsor's HAML form does.
    #: (SponsorshipRequest?, String) { () -> SponsorshipRequest } -> void
    private def assign_request(request, body, &build)
      if body.blank?
        request&.mark_for_destruction
      else
        (request || build.call).body = body
      end
    end
  end
end
