# typed: strict
# frozen_string_literal: true

module Api
  module Sponsor
    # For RPCs a visitor reaches before applying: the conference applied to, and the logo files this
    # browser uploaded for an application.
    # @requires_ancestor: Api::Sponsor::ApplicationController
    module ApplicationLookup
      # The conference the request names. A hidden one is not found, exactly as an unknown slug is,
      # unless the invitation code matches or the session sponsors it already.
      #: (String) -> Conference
      private def find_application_conference(invite_code)
        slug = connect_request.conference_slug #: String
        conference = Conference.find_by(slug:)
        return conference if conference && (conference.verify_invite_code(invite_code) || current_sponsorship_maybe)

        raise Errors::NotFound.new(detail: "No conference has the slug #{slug.inspect}.")
      end

      # Logo files uploaded in this browser that no application has claimed yet.
      #: () -> Array[Integer]
      private def session_asset_file_ids = Array(session[:asset_file_ids])

      # A logo file of one of the sponsorships, or one uploaded in this browser and unclaimed. Any
      # other is not found, so a file ID alone grants nothing.
      #: (Integer, sponsorship_ids: Array[Integer]) -> SponsorshipAssetFile
      private def find_session_asset_file(id, sponsorship_ids:)
        asset_file = SponsorshipAssetFile
          .available_for_user(id, session_asset_file_ids:, available_sponsorship_ids: sponsorship_ids)
          .first #: SponsorshipAssetFile?
        asset_file || raise(Errors::NotFound.new(detail: "This browser has no logo file #{id}."))
      end

      # Whether an application to the conference may use the file: a sponsorship's own, or an
      # unclaimed one uploaded for the conference.
      #: (SponsorshipAssetFile, Conference) -> bool
      private def asset_file_for?(asset_file, conference) = !asset_file.sponsorship_id.nil? || asset_file.prepared_for?(conference)
    end
  end
end
