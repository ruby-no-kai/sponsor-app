# typed: strict
# frozen_string_literal: true

module Api
  module Admin
    class AnnouncementsController < Api::Admin::ApplicationController
      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceListAnnouncementsResponse
      def list_announcements
        Rk::SponsorApp::AdminServiceListAnnouncementsResponse.new(
          issues: AnnouncementIssue.all_of(conference).map { Api::AdminAnnouncementIssueResource.new(it).as_protobuf },
        )
      end

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceGetAnnouncementResponse
      def get_announcement
        announcement = find_announcement

        Rk::SponsorApp::AdminServiceGetAnnouncementResponse.new(
          announcement: admin_announcement_message(announcement),
          issue: Api::AdminAnnouncementIssueResource.new(AnnouncementIssue.of(announcement)).as_protobuf,
        )
      end

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceCreateAnnouncementResponse
      def create_announcement
        issue = (connect_request.issue if connect_request.has_issue?) #: String?
        input = connect_request.input #: Rk::SponsorApp::AnnouncementInput
        announcement = conference.announcements.build(staff: current_staff)
        if issue
          unless conference.announcements.exists?(issue:)
            raise Errors::NotFound.new(detail: "The conference #{conference.slug.inspect} has no announcement issue #{issue.inspect}.")
          end

          announcement.issue = issue
        end
        save_input!(announcement, input)

        Rk::SponsorApp::AdminServiceCreateAnnouncementResponse.new(announcement: admin_announcement_message(announcement))
      end

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceUpdateAnnouncementResponse
      def update_announcement
        input = connect_request.input #: Rk::SponsorApp::AnnouncementInput
        announcement = find_announcement
        save_input!(announcement, input)

        Rk::SponsorApp::AdminServiceUpdateAnnouncementResponse.new(announcement: admin_announcement_message(announcement))
      end

      #: () -> Announcement
      private def find_announcement
        issue = connect_request.issue #: String
        locale = connect_request.locale #: String
        conference.announcements.find_by(issue:, locale:) || raise(Errors::NotFound.new(
          detail: "The conference #{conference.slug.inspect} has no announcement #{issue.inspect} in #{locale.inspect}.",
        ))
      end

      # A validation failure raises ActiveRecord::RecordInvalid, which is answered as
      # Errors::InvalidRecord on the input's fields.
      #: (Announcement, Rk::SponsorApp::AnnouncementInput) -> void
      private def save_input!(announcement, input)
        announcement.assign_attributes(
          locale: input.locale,
          title: input.title,
          body: input.body,
          # A pinned announcement keeps a stickiness above one, which orders it among the pinned ones.
          stickiness: input.pinned ? [announcement.stickiness, 1].max : 0,
          exhibitors_only: input.exhibitors_only,
          published: input.published,
          new_revision: input.new_revision,
        )
        announcement.save!
      rescue ActiveRecord::RecordNotUnique
        raise Errors::Conflict.new(
          detail: "The announcement #{announcement.issue.inspect} is already written in #{input.locale.inspect}.",
        )
      end

      #: (Announcement) -> Rk::SponsorApp::AdminAnnouncement
      private def admin_announcement_message(announcement)
        sponsor_page_url = user_conference_sponsorship_url(conference, anchor: "announcement-#{announcement.issue}")
        Api::AdminAnnouncementResource.new(announcement, params: {sponsor_page_url:}).as_protobuf
      end
    end
  end
end
