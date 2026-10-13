# typed: strict
# frozen_string_literal: true

module Api
  module Admin
    # An organization spans conferences, so restricted staff may use none of these.
    class OrganizationsController < Api::Admin::ApplicationController
      authorize :unrestricted_staff
      #: () -> Rk::SponsorApp::AdminServiceListOrganizationsResponse
      def list_organizations
        organizations = Organization.with_sponsorship_count.order(:name, :id)

        Rk::SponsorApp::AdminServiceListOrganizationsResponse.new(
          organizations: organizations.map { admin_organization_message(it) },
        )
      end

      authorize :unrestricted_staff
      #: () -> Rk::SponsorApp::AdminServiceGetOrganizationResponse
      def get_organization
        organization = find_organization
        conferences = Conference.application_open.order(id: :desc)
        sponsorships = organization.sponsorships.includes(:conference, :plan).order(id: :desc)

        Rk::SponsorApp::AdminServiceGetOrganizationResponse.new(
          organization: admin_organization_message(organization),
          affiliation_urls: conferences.map { Api::OrganizationAffiliationUrlResource.new(it, params: {organization:}).as_protobuf },
          sponsorships: sponsorships.map { Api::OrganizationSponsorshipResource.new(it).as_protobuf },
        )
      end

      authorize :unrestricted_staff
      #: () -> Rk::SponsorApp::AdminServiceCreateOrganizationResponse
      def create_organization
        input = connect_request.input #: Rk::SponsorApp::OrganizationInput
        organization = Organization.new
        save_input!(organization, input)

        Rk::SponsorApp::AdminServiceCreateOrganizationResponse.new(organization: admin_organization_message(organization))
      end

      authorize :unrestricted_staff
      #: () -> Rk::SponsorApp::AdminServiceUpdateOrganizationResponse
      def update_organization
        input = connect_request.input #: Rk::SponsorApp::OrganizationInput
        organization = find_organization
        save_input!(organization, input)

        Rk::SponsorApp::AdminServiceUpdateOrganizationResponse.new(organization: admin_organization_message(organization))
      end

      #: () -> Organization
      private def find_organization
        domain = connect_request.domain #: String
        Organization.with_sponsorship_count.find_by(domain:) ||
          raise(Errors::NotFound.new(detail: "No organization has the domain #{domain.inspect}."))
      end

      # A validation failure raises ActiveRecord::RecordInvalid, which is answered as
      # Errors::InvalidRecord on the input's fields.
      #: (Organization, Rk::SponsorApp::OrganizationInput) -> void
      private def save_input!(organization, input)
        organization.update!(
          name: input.name,
          domain: input.domain,
          auto_acceptance_disabled: input.auto_acceptance_disabled,
        )
      rescue ActiveRecord::RecordNotUnique
        # Only a concurrent save gets past the domain's uniqueness validation.
        raise Errors::Conflict.new(detail: "Another organization has the domain #{input.domain.inspect}.")
      end

      #: (Organization) -> Rk::SponsorApp::AdminOrganization
      private def admin_organization_message(organization)
        Api::AdminOrganizationResource.new(organization).as_protobuf
      end
    end
  end
end
