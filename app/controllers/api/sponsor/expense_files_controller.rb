# typed: strict
# frozen_string_literal: true

module Api
  module Sponsor
    # The browser sends the file itself straight to the storage, with the presigned POST these RPCs
    # hand out. Previews and downloads stay with the HAML area's expense_files page, which
    # redirects to a presigned GET.
    class ExpenseFilesController < Api::Sponsor::ApplicationController
      include Api::Sponsor::ExpenseReportLookup

      authorize :sponsorship
      #: () -> Rk::SponsorApp::SponsorServiceCreateExpenseFileUploadResponse
      def create_expense_file_upload
        input = connect_request.input #: Rk::SponsorApp::ExpenseFileUploadInput
        sponsorship = custom_sponsorship
        refuse_unless_editable!(sponsorship.expense_report)

        file = ExpenseFile.prepare(conference: Must.expect(sponsorship.conference), sponsorship:)
        file.assign_attributes(filename: input.filename, content_type: input.content_type)
        file.save!

        Rk::SponsorApp::SponsorServiceCreateExpenseFileUploadResponse.new(upload: upload_message(file))
      end

      authorize :sponsorship
      #: () -> Rk::SponsorApp::SponsorServiceInitiateExpenseFileUpdateResponse
      def initiate_expense_file_update
        content_type = (connect_request.content_type if connect_request.has_content_type?) #: String?
        sponsorship = custom_sponsorship
        refuse_unless_editable!(sponsorship.expense_report)

        file = find_file(sponsorship)
        # Pins the presigned POST only. The content type stored comes from the storage on completion.
        file.content_type = content_type if content_type

        Rk::SponsorApp::SponsorServiceInitiateExpenseFileUpdateResponse.new(upload: upload_message(file))
      end

      authorize :sponsorship
      #: () -> Rk::SponsorApp::SponsorServiceCompleteExpenseFileUploadResponse
      def complete_expense_file_upload
        filename = (connect_request.filename if connect_request.has_filename?) #: String?
        version_id = connect_request.version_id #: String
        extension = connect_request.extension #: String
        sponsorship = custom_sponsorship
        refuse_unless_editable!(sponsorship.expense_report)

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

        Rk::SponsorApp::SponsorServiceCompleteExpenseFileUploadResponse.new(
          file: Api::ExpenseFileResource.new(file).as_protobuf,
        )
      end

      authorize :sponsorship
      #: () -> Rk::SponsorApp::SponsorServiceDeleteExpenseFileResponse
      def delete_expense_file
        sponsorship = custom_sponsorship
        file = find_file(sponsorship)

        ActiveRecord::Base.transaction do
          report = sponsorship.expense_report
          lock_editable!(report) if report
          attached = file.expense_line_item_files.exists?
          file.destroy!
          # A rejected report changes with the files its line items attach.
          if report && attached
            report.reopen_if_rejected
            report.save!
          end
        end

        Rk::SponsorApp::SponsorServiceDeleteExpenseFileResponse.new
      end

      # A file of another sponsorship is not found.
      #: (Sponsorship) -> ExpenseFile
      private def find_file(sponsorship)
        id = connect_request.file_id #: Integer
        sponsorship.expense_files.find_by(id:) || raise(Errors::NotFound.new(detail: "The sponsorship has no expense file #{id}."))
      end

      #: (ExpenseFile) -> Rk::SponsorApp::ExpenseFileUpload
      private def upload_message(file)
        Api::ExpenseFileUploadResource.new(file.make_session).as_protobuf
      end
    end
  end
end
