# typed: strict
# frozen_string_literal: true

module Api
  module Admin
    # For RPCs under `authorize :conference` that queue CreateBroadcastDeliveriesJob with the
    # recipients a BroadcastRecipientFilter selects.
    # @requires_ancestor: Api::Admin::ApplicationController
    module BroadcastRecipientFilterArgument
      # The job's argument for a filter, copied field by field into the job's internal message.
      # The plan, sponsorships or past conference a filter names are checked here, as the job trusts
      # its argument.
      #: (Rk::SponsorApp::BroadcastRecipientFilter) -> Rk::SponsorApp::Internal::BroadcastRecipientFilter
      private def recipient_filter_argument(filter)
        case filter.kind
        when :current_sponsors
          sub = Must.because(filter.current_sponsors) { 'kind names the field that is set' }
          Rk::SponsorApp::Internal::BroadcastRecipientFilter.new(current_sponsors: current_sponsors_filter(sub))
        when :past_sponsors
          sub = Must.because(filter.past_sponsors) { 'kind names the field that is set' }
          Rk::SponsorApp::Internal::BroadcastRecipientFilter.new(past_sponsors: past_sponsors_filter(sub))
        when :manual
          sub = Must.because(filter.manual) { 'kind names the field that is set' }
          Rk::SponsorApp::Internal::BroadcastRecipientFilter.new(manual: manual_filter(sub))
        when :raw
          sub = Must.because(filter.raw) { 'kind names the field that is set' }
          Rk::SponsorApp::Internal::BroadcastRecipientFilter.new(raw: raw_filter(sub))
        else
          raise ArgumentError, "unknown recipient filter kind: #{filter.kind.inspect}"
        end
      end

      #: (Rk::SponsorApp::BroadcastRecipientFilter::CurrentSponsors) -> Rk::SponsorApp::Internal::BroadcastRecipientFilter::CurrentSponsors
      private def current_sponsors_filter(filter)
        Rk::SponsorApp::Internal::BroadcastRecipientFilter::CurrentSponsors.new(
          locale: (filter.locale if filter.has_locale?),
          exhibitors_only: filter.exhibitors_only,
          plan_id: (filter_plan(filter.plan_id).id if filter.has_plan_id?),
          status: filter.status,
        )
      end

      # The job does not apply exclude_current_sponsors to past sponsors yet.
      #: (Rk::SponsorApp::BroadcastRecipientFilter::PastSponsors) -> Rk::SponsorApp::Internal::BroadcastRecipientFilter::PastSponsors
      private def past_sponsors_filter(filter)
        Rk::SponsorApp::Internal::BroadcastRecipientFilter::PastSponsors.new(
          conference_id: accessible_conference!(filter.conference_slug).id,
          locale: (filter.locale if filter.has_locale?),
          exclude_current_sponsors: filter.exclude_current_sponsors,
          status: filter.status,
        )
      end

      #: (Rk::SponsorApp::BroadcastRecipientFilter::Manual) -> Rk::SponsorApp::Internal::BroadcastRecipientFilter::Manual
      private def manual_filter(filter)
        ids = filter.sponsorship_ids.to_a
        foreign = ids - conference.sponsorships.where(id: ids).pluck(:id)
        unless foreign.empty?
          raise Errors::NotFound.new(
            detail: "The conference #{conference.slug.inspect} has none of the sponsorships #{foreign.join(', ')}.",
          )
        end

        Rk::SponsorApp::Internal::BroadcastRecipientFilter::Manual.new(sponsorship_ids: ids)
      end

      #: (Rk::SponsorApp::BroadcastRecipientFilter::Raw) -> Rk::SponsorApp::Internal::BroadcastRecipientFilter::Raw
      private def raw_filter(filter)
        Rk::SponsorApp::Internal::BroadcastRecipientFilter::Raw.new(emails: filter.emails.to_a)
      end

      # The job drops a plan filter naming another conference's plan, widening it to every plan.
      #: (Integer) -> Plan
      private def filter_plan(id)
        conference.plans.find_by(id:) || raise(Errors::NotFound.new(
          detail: "The conference #{conference.slug.inspect} has no plan #{id}.",
        ))
      end
    end
  end
end
