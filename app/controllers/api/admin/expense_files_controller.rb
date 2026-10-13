# typed: strict
# frozen_string_literal: true

module Api
  module Admin
    # The browser sends the file itself straight to the storage, with the presigned POST these
    # RPCs hand out. Previews and downloads stay with the staff area's expense file page, which
    # redirects to a presigned GET.
    class ExpenseFilesController < Api::Admin::ApplicationController
      include Api::Admin::SponsorshipLookup
      include Api::Admin::ExpenseReportLookup

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceCreateExpenseFileUploadResponse
      def create_expense_file_upload
        input = connect_request.input #: Rk::SponsorApp::ExpenseFileUploadInput
        sponsorship = find_sponsorship
        refuse_approved!(sponsorship.expense_report)

        file = ExpenseFile.prepare(conference:, sponsorship:)
        file.assign_attributes(filename: input.filename, content_type: input.content_type)
        file.save!

        Rk::SponsorApp::AdminServiceCreateExpenseFileUploadResponse.new(upload: upload_message(file))
      end

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceInitiateExpenseFileUpdateResponse
      def initiate_expense_file_update
        content_type = (connect_request.content_type if connect_request.has_content_type?) #: String?
        sponsorship = find_sponsorship
        refuse_approved!(sponsorship.expense_report)

        file = find_file(sponsorship)
        # Pins the presigned POST only. The content type stored comes from the storage on completion.
        file.content_type = content_type if content_type

        Rk::SponsorApp::AdminServiceInitiateExpenseFileUpdateResponse.new(upload: upload_message(file))
      end

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceCompleteExpenseFileUploadResponse
      def complete_expense_file_upload
        filename = (connect_request.filename if connect_request.has_filename?) #: String?
        version_id = connect_request.version_id #: String
        extension = connect_request.extension #: String
        sponsorship = find_sponsorship
        refuse_approved!(sponsorship.expense_report)

        file = find_file(sponsorship)
        file.filename = filename if filename
        file.version_id = version_id unless version_id.empty?
        file.extension = extension.downcase.gsub(/[^a-z0-9]/, '').presence || 'unknown'
        file.status = 'uploaded'
        begin
          file.update_object_header
        rescue Aws::S3::Errors::NotFound
          raise Errors::FailedPrecondition.new(detail: "The storage holds no upload of the expense file #{file.id} yet.")
        end
        file.save!

        Rk::SponsorApp::AdminServiceCompleteExpenseFileUploadResponse.new(
          file: Api::ExpenseFileResource.new(file).as_protobuf,
        )
      end

      authorize :conference
      #: () -> Rk::SponsorApp::AdminServiceDeleteExpenseFileResponse
      def delete_expense_file
        sponsorship = find_sponsorship
        file = find_file(sponsorship)

        ActiveRecord::Base.transaction do
          report = sponsorship.expense_report
          lock_unapproved!(report) if report
          file.destroy!
          # The snapshot under review lists each line item's files.
          report&.refresh_submission_snapshot
        end

        Rk::SponsorApp::AdminServiceDeleteExpenseFileResponse.new
      end

      # A file of another sponsorship is not found, even one of the same conference.
      #: (Sponsorship) -> ExpenseFile
      private def find_file(sponsorship)
        id = connect_request.file_id #: Integer
        sponsorship.expense_files.find_by(id:) || raise(Errors::NotFound.new(
          detail: "The sponsorship #{sponsorship.id} has no expense file #{id}.",
        ))
      end

      #: (ExpenseFile) -> Rk::SponsorApp::ExpenseFileUpload
      private def upload_message(file)
        Api::ExpenseFileUploadResource.new(file.make_session).as_protobuf
      end
    end
  end
end
