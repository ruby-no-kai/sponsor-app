# typed: strict
# frozen_string_literal: true

module Api
  module Sponsor
    # The booth details a sponsor submits for the booth it is assigned.
    class ExhibitionsController < Api::Sponsor::ApplicationController
      authorize :sponsorship
      #: () -> Rk::SponsorApp::SponsorServiceCreateExhibitionResponse
      def create_exhibition
        input = connect_request.input #: Rk::SponsorApp::ExhibitionInput
        sponsorship = current_sponsorship
        require_booth!

        # The table has no unique index, so a double submit is serialized on the sponsorship.
        exhibition = sponsorship.with_lock do
          if Exhibition.exists?(sponsorship:)
            raise Errors::Conflict.new(detail: 'The sponsorship has booth details already, which UpdateExhibition changes.')
          end

          Exhibition.new(sponsorship:, description: input.description).tap(&:save!)
        end
        notify_organizers('submitted')

        Rk::SponsorApp::SponsorServiceCreateExhibitionResponse.new(
          exhibition: Api::ExhibitionResource.new(exhibition).as_protobuf,
        )
      end

      authorize :sponsorship
      #: () -> Rk::SponsorApp::SponsorServiceUpdateExhibitionResponse
      def update_exhibition
        input = connect_request.input #: Rk::SponsorApp::ExhibitionInput
        sponsorship = current_sponsorship
        exhibition = sponsorship.exhibition || raise(Errors::NotFound.new(detail: 'The sponsorship has no booth details yet.'))
        require_booth!

        exhibition.update!(description: input.description)
        notify_organizers('edited')

        Rk::SponsorApp::SponsorServiceUpdateExhibitionResponse.new(
          exhibition: Api::ExhibitionResource.new(exhibition).as_protobuf,
        )
      end

      #: () -> void
      private def require_booth!
        return if current_sponsorship.booth_assigned?

        raise Errors::FailedPrecondition.new(detail: 'The sponsorship has no booth assigned.')
      end

      #: (String) -> void
      private def notify_organizers(action)
        sponsorship = current_sponsorship
        SlackWebhookJob.perform_later(
          {
            text: ":customs: <#{conference_sponsorship_url(event_conference, sponsorship)}|#{sponsorship.name}> booth details #{action} by sponsor",
          },
          hook_name: 'feed',
        )
      end

      #: () -> Conference
      private def event_conference = Must.expect(current_sponsorship.conference)
    end
  end
end
