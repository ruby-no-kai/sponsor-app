# typed: strict
# frozen_string_literal: true

module Api
  module Sponsor
    class SponsorshipsController < Api::Sponsor::ApplicationController
      authorize :sponsorship
      #: () -> Rk::SponsorApp::SponsorServiceGetSponsorshipResponse
      def get_sponsorship
        sponsorship = current_sponsorship
        ActiveRecord::Associations::Preloader.new(
          records: [sponsorship],
          associations: [:conference, :plan, :exhibition, :expense_report, :tito_discount_codes, :sponsor_events],
        ).call
        conference = Must.expect(sponsorship.conference)

        Rk::SponsorApp::SponsorServiceGetSponsorshipResponse.new(
          conference: Api::ConferenceResource.new(conference).as_protobuf,
          sponsorship: Api::SponsorshipResource.new(sponsorship).as_protobuf,
          amendment_open: !!conference.amendment_open?,
          event_submission_open: !!conference.event_submission_open?,
          distributing_tickets: !!conference.distributing_ticket?,
          tickets_on_tito: conference.tito_slug.present?,
          exhibition: exhibition_message(sponsorship),
          sponsor_events: sponsor_events_message(sponsorship),
          expense_report: expense_report_message(sponsorship),
          tickets: tickets_message(sponsorship),
          announcements: announcements_for(sponsorship).map { Api::AnnouncementResource.new(it).as_protobuf },
        )
      end

      #: (Sponsorship) -> Rk::SponsorApp::Exhibition?
      private def exhibition_message(sponsorship)
        exhibition = sponsorship.exhibition
        return unless sponsorship.booth_assigned? && exhibition

        Api::ExhibitionResource.new(exhibition).as_protobuf
      end

      #: (Sponsorship) -> Rk::SponsorApp::SponsorServiceGetSponsorshipResponse::SponsorEvents?
      private def sponsor_events_message(sponsorship)
        return unless sponsorship.accepted?

        events = sponsorship.sponsor_events.sort_by { [it.starts_at, it.id] }
        return if events.empty? && !Must.expect(sponsorship.conference).event_submission_open?

        Rk::SponsorApp::SponsorServiceGetSponsorshipResponse::SponsorEvents.new(
          events: events.map { Api::SponsorEventSummaryResource.new(it).as_protobuf },
        )
      end

      # Only for a confirmed package with a name, while the report's own pages admit any confirmed
      # package.
      #: (Sponsorship) -> Rk::SponsorApp::ExpenseReportSummary?
      private def expense_report_message(sponsorship)
        report = sponsorship.expense_report
        return unless sponsorship.customized? && report

        Api::ExpenseReportSummaryResource.new(report).as_protobuf
      end

      #: (Sponsorship) -> Rk::SponsorApp::SponsorServiceGetSponsorshipResponse::Tickets?
      private def tickets_message(sponsorship)
        conference = Must.expect(sponsorship.conference)
        return unless conference.distributing_ticket?
        return unless sponsorship.booth_assigned? || sponsorship.total_number_of_attendees > 0

        codes = conference.tito_slug.present? ? sponsorship.tito_discount_codes : []
        Rk::SponsorApp::SponsorServiceGetSponsorshipResponse::Tickets.new(
          discount_codes: codes.sort_by { TitoDiscountCode.kinds.fetch(it.kind) }.map { Api::TitoDiscountCodeResource.new(it).as_protobuf },
        )
      end

      #: (Sponsorship) -> Announcement::PrivateRelation
      private def announcements_for(sponsorship)
        Announcement
          .where(conference_id: sponsorship.conference_id, locale: I18n.locale.to_s)
          .where.not(published_at: nil)
          .merge(sponsorship.exhibitor? ? Announcement.for_exhibitors : Announcement.for_sponsors)
          .order(stickiness: :desc, id: :desc)
      end
    end
  end
end
