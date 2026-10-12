# typed: strict
# frozen_string_literal: true

module Api
  class AdminSponsorshipResource < Api::ApplicationResource
    with_protobuf Rk::SponsorApp::AdminSponsorship do
      attributes :id, :name, :suspended, :locale, :fallback_option, :customization, :booth_requested, :booth_assigned,
        :url, :profile, :word_count
      attribute(:state) { |sponsorship| Api::SponsorshipSummaryResource.state_of(sponsorship) }
      attributes accepted_at: :timestamp, if: proc { |sponsorship| sponsorship.accepted_at }
      attributes withdrawn_at: :timestamp, if: proc { |sponsorship| sponsorship.withdrawn_at }
      one :organization, resource: Api::OrganizationSummaryResource
      attribute(:asset_file_uploaded) { |sponsorship| !sponsorship.asset_file.nil? }

      one :plan, resource: Api::AdminSponsorshipPlanResource, if: proc { |sponsorship| sponsorship.plan }
      attributes :customization_name, if: proc { |sponsorship| sponsorship.customization_name.present? }

      attribute(:included_attendees) { |sponsorship| sponsorship.plan&.number_of_guests || 0 }
      attributes :number_of_additional_attendees, if: proc { |sponsorship| sponsorship.number_of_additional_attendees }
      attribute(:total_attendees, &:total_number_of_attendees)
      # The codes link to the conference's event on the ticketing service, which tito_slug names.
      attribute(:tito_discount_codes) do |sponsorship|
        next [] if Must.expect(sponsorship.conference).tito_slug.blank?

        sponsorship.tito_discount_codes.order(:kind).map { Api::AdminSponsorshipTitoDiscountCodeResource.new(it).as_protobuf }
      end

      attribute(:customization_request) { |sponsorship| sponsorship.customization_request&.body.to_s }
      attribute(:billing_request) { |sponsorship| sponsorship.billing_request&.body.to_s }
      attribute(:note) { |sponsorship| sponsorship.note&.body.to_s }

      attribute(:exhibition_description, if: proc { |sponsorship| sponsorship.exhibition }) do |sponsorship|
        sponsorship.exhibition&.description.to_s
      end
      attribute(:sponsor_events) do |sponsorship|
        sponsorship.sponsor_events.by_starts_at.map { Api::AdminSponsorshipSponsorEventResource.new(it).as_protobuf }
      end
      # Expenses are reported for a custom package only.
      one :expense_report, resource: Api::AdminSponsorshipExpenseReportResource,
        if: proc { |sponsorship| sponsorship.customization_name.present? && sponsorship.expense_report }

      one :contact, resource: Api::AdminSponsorshipContactResource
      one :alternate_billing_contact, resource: Api::AdminSponsorshipContactResource,
        if: proc { |sponsorship| sponsorship.alternate_billing_contact }
    end
  end
end
