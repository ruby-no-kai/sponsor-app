# typed: strict
# frozen_string_literal: true

module Api
  module Admin
    class BoothAssignmentsController < Api::Admin::ApplicationController
      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceGetBoothAssignmentResponse
      def get_booth_assignment
        Rk::SponsorApp::AdminServiceGetBoothAssignmentResponse.new(
          booth_assignment: booth_assignment_message(BoothAssignment.new(conference)),
        )
      end

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceUpdateBoothAssignmentResponse
      def update_booth_assignment
        input = connect_request.input #: Rk::SponsorApp::BoothAssignmentInput
        booth_assignment = BoothAssignment.new(conference)
        begin
          booth_assignment.assign!(input.assigned_sponsorship_ids.to_a, staff: current_staff)
        rescue BoothAssignment::UnknownSponsorships => e
          # Answered alike for another conference's sponsorship and a missing one, telling neither apart.
          raise Errors::NotFound.new(detail: "The conference #{conference.slug.inspect} has no sponsorship #{e.ids.join(', ')}.")
        rescue BoothAssignment::InactiveSponsorships => e
          raise Errors::FailedPrecondition.new(
            detail: "No booth can be assigned to a sponsorship that has withdrawn or awaits acceptance: #{e.ids.join(', ')}.",
          )
        end

        Rk::SponsorApp::AdminServiceUpdateBoothAssignmentResponse.new(
          booth_assignment: booth_assignment_message(booth_assignment),
        )
      end

      #: (BoothAssignment) -> Rk::SponsorApp::BoothAssignment
      private def booth_assignment_message(booth_assignment)
        Api::BoothAssignmentResource.new(booth_assignment).as_protobuf
      end
    end
  end
end
