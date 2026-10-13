# typed: strict
# frozen_string_literal: true

module Api
  module Sponsor
    # The browser sends the image itself straight to the storage, with the presigned POST these RPCs
    # hand out. Downloads stay with the HAML area's event_asset_files page.
    class SponsorEventAssetFilesController < Api::Sponsor::ApplicationController
      include Api::Sponsor::SponsorEventGates

      authorize :sponsorship
      #: () -> Rk::SponsorApp::SponsorServiceCreateSponsorEventAssetUploadResponse
      def create_sponsor_event_asset_upload
        content_type = (connect_request.content_type if connect_request.has_content_type?) #: String?
        require_event_submission_open!

        asset_file = SponsorEventAssetFile.prepare(conference: event_conference, sponsorship: current_sponsorship)
        asset_file.content_type = content_type
        asset_file.save!

        Rk::SponsorApp::SponsorServiceCreateSponsorEventAssetUploadResponse.new(upload: upload_message(asset_file))
      end

      authorize :sponsorship
      #: () -> Rk::SponsorApp::SponsorServiceInitiateSponsorEventAssetUpdateResponse
      def initiate_sponsor_event_asset_update
        content_type = (connect_request.content_type if connect_request.has_content_type?) #: String?
        require_event_submission_open!
        asset_file = find_asset_file

        # Pins the presigned POST only. The content type stored comes from the storage on completion.
        asset_file.content_type = content_type if content_type

        Rk::SponsorApp::SponsorServiceInitiateSponsorEventAssetUpdateResponse.new(upload: upload_message(asset_file))
      end

      authorize :sponsorship
      #: () -> Rk::SponsorApp::SponsorServiceCompleteSponsorEventAssetUploadResponse
      def complete_sponsor_event_asset_upload
        version_id = connect_request.version_id #: String
        extension = connect_request.extension #: String
        require_event_submission_open!
        asset_file = find_asset_file

        asset_file.version_id = version_id unless version_id.empty?
        asset_file.extension = extension.downcase.gsub(/[^a-z0-9]/, '').presence || 'unknown'
        begin
          asset_file.update_object_header
        rescue Aws::S3::Errors::NotFound
          raise Errors::FailedPrecondition.new(detail: "The storage holds no upload of the event image #{asset_file.id} yet.")
        end
        asset_file.save!

        Rk::SponsorApp::SponsorServiceCompleteSponsorEventAssetUploadResponse.new(
          asset_file: Api::SponsorEventAssetFileResource.new(asset_file).as_protobuf,
        )
      end

      #: () -> SponsorEventAssetFile
      private def find_asset_file
        id = connect_request.asset_file_id #: Integer
        asset_file = SponsorEventAssetFile.find_by(id:, sponsorship: current_sponsorship) ||
          raise(Errors::NotFound.new(detail: "The sponsorship has no event image #{id}."))
        event = asset_file.sponsor_event
        if event && !event.editable_by_sponsor?
          raise Errors::FailedPrecondition.new(detail: "The event of the image #{id} is no longer editable.")
        end
        asset_file
      end

      #: (SponsorEventAssetFile) -> Rk::SponsorApp::AssetUpload
      private def upload_message(asset_file)
        Api::AssetUploadResource.new(asset_file.make_session).as_protobuf
      end
    end
  end
end
