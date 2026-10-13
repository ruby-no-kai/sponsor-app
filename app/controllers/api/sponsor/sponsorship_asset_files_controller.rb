# typed: strict
# frozen_string_literal: true

module Api
  module Sponsor
    # The browser sends the logo itself straight to the storage, with the presigned POST these RPCs
    # hand out. Downloads stay with the HAML area's sponsorship_asset_files page, which redirects to
    # a presigned GET.
    class SponsorshipAssetFilesController < Api::Sponsor::ApplicationController
      include Api::Sponsor::ApplicationLookup

      # A visitor uploads the logo before applying, so no session is needed. The file is remembered
      # for this browser until an application claims it.
      authorize :public
      #: () -> Rk::SponsorApp::SponsorServiceCreateSponsorshipAssetUploadResponse
      def create_sponsorship_asset_upload
        invite_code = connect_request.invite_code #: String
        content_type = (connect_request.content_type if connect_request.has_content_type?) #: String?
        conference = find_application_conference(invite_code)
        if current_sponsorship_maybe&.asset_file
          raise Errors::FailedPrecondition.new(
            detail: 'Your sponsorship has a logo already, which InitiateSponsorshipAssetUpdate replaces.',
          )
        end
        require_upload_window!(conference)

        asset_file = SponsorshipAssetFile.prepare(conference:)
        asset_file.content_type = content_type
        asset_file.save!
        session[:asset_file_ids] = [*session_asset_file_ids, asset_file.id]

        Rk::SponsorApp::SponsorServiceCreateSponsorshipAssetUploadResponse.new(upload: upload_message(asset_file))
      end

      authorize :public
      #: () -> Rk::SponsorApp::SponsorServiceInitiateSponsorshipAssetUpdateResponse
      def initiate_sponsorship_asset_update
        content_type = (connect_request.content_type if connect_request.has_content_type?) #: String?
        asset_file = find_asset_file
        require_upload_window!(find_conference(asset_file))

        # Pins the presigned POST only. The content type stored comes from the storage on completion.
        asset_file.content_type = content_type if content_type

        Rk::SponsorApp::SponsorServiceInitiateSponsorshipAssetUpdateResponse.new(upload: upload_message(asset_file))
      end

      # The upload went through already, so a closed window does not stop it being recorded.
      authorize :public
      #: () -> Rk::SponsorApp::SponsorServiceCompleteSponsorshipAssetUploadResponse
      def complete_sponsorship_asset_upload
        version_id = connect_request.version_id #: String
        extension = connect_request.extension #: String
        asset_file = find_asset_file
        find_conference(asset_file)

        asset_file.version_id = version_id unless version_id.empty?
        asset_file.extension = extension.downcase.gsub(/[^a-z0-9]/, '').presence || 'unknown'
        begin
          asset_file.update_object_header
        rescue Aws::S3::Errors::NotFound
          raise Errors::FailedPrecondition.new(detail: "The storage holds no upload of the logo file #{asset_file.id} yet.")
        end
        asset_file.save!

        Rk::SponsorApp::SponsorServiceCompleteSponsorshipAssetUploadResponse.new(
          asset_file: Api::SponsorshipAssetFileResource.new(asset_file).as_protobuf,
        )
      end

      # Looked up before the conference, which find_conference checks it against.
      #: () -> SponsorshipAssetFile
      private def find_asset_file
        id = connect_request.asset_file_id #: Integer
        find_session_asset_file(id, sponsorship_ids: [current_sponsorship_maybe&.id].compact)
      end

      # The conference the request names, if the file is for it. Otherwise it is not found, as an
      # unknown slug is, so that a hidden conference's slug tells nothing to a browser with a file
      # of another conference.
      #: (SponsorshipAssetFile) -> Conference
      private def find_conference(asset_file)
        slug = connect_request.conference_slug #: String
        conference = Conference.find_by(slug:)
        return conference if conference && asset_file_for?(asset_file, conference)

        raise Errors::NotFound.new(detail: "No conference has the slug #{slug.inspect}.")
      end

      # Uploads open with applications and close with amendments, except for staff.
      #: (Conference) -> void
      private def require_upload_window!(conference)
        return if conference.amendment_open? || current_staff_maybe

        raise Errors::FailedPrecondition.new(detail: "The conference #{conference.slug.inspect} takes no amendments now.")
      end

      #: (SponsorshipAssetFile) -> Rk::SponsorApp::AssetUpload
      private def upload_message(asset_file)
        Api::AssetUploadResource.new(asset_file.make_session).as_protobuf
      end
    end
  end
end
