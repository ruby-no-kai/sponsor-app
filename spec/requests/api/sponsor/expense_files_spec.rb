# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SponsorService expense files', type: :request do
  let(:conference) { FactoryBot.create(:conference) }
  let(:plan) { FactoryBot.create(:plan, conference:) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:, customization: true) }
  let(:other_sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:, customization: true) }
  let!(:report) { FactoryBot.create(:expense_report, sponsorship:) }
  let(:head_object) do
    {version_id: 'v2', last_modified: Time.zone.parse('2026-10-01 10:00:00'), checksum_sha256: 'c3Vt', content_type: 'image/png'}
  end
  let(:s3_client) { Aws::S3::Client.new(stub_responses: {head_object:}, region: 'ap-northeast-1') }

  before do
    allow(Aws::STS::Client).to receive(:new).and_return(Aws::STS::Client.new(stub_responses: true, region: 'ap-northeast-1'))
    allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
    sign_in_sponsor(sponsorship.contact.email)
  end

  def pending_file(**attributes)
    ExpenseFile.prepare(conference:, sponsorship:).tap do |file|
      file.assign_attributes(filename: 'receipt.pdf', content_type: 'application/pdf', **attributes)
      file.save!
    end
  end

  def expect_upload_for(upload, file, content_type:)
    expect(upload).to have_attributes(file_id: file.id, max_size: 20.megabytes)
    expect(upload.url).to start_with('https://')
    expect(upload.fields.to_h).to include('key' => file.object_key, 'Content-Type' => content_type)
  end

  shared_examples 'an RPC refused while the report is under review or approved' do
    %w[submitted approved].each do |status|
      it "answers failed_precondition for a #{status} report" do
        report.update!(status:)

        error = connect_call(rpc, rpc_request)

        expect(error).to have_attributes(status: 400, code: 'failed_precondition')
        expect(problem_type_of(error)).to eq('failed-precondition')
      end
    end

    it 'takes the call while the report is rejected, leaving its status to the line item changes' do
      report.update!(status: 'rejected')

      expect(connect_call(rpc, rpc_request)).not_to be_a(ConnectHelper::ConnectError)
      expect(report.reload.status).to eq('rejected')
    end

    it 'answers permission_denied to a sponsorship that is not custom' do
      sponsorship.update!(customization: false)

      expect(connect_call(rpc, rpc_request)).to have_attributes(status: 403, code: 'permission_denied')
    end

    it 'answers unauthenticated without a sponsor session' do
      reset!

      expect(connect_call(rpc, rpc_request)).to have_attributes(status: 401, code: 'unauthenticated')
    end
  end

  describe 'CreateExpenseFileUpload' do
    let(:rpc) { connect_method('SponsorService', 'CreateExpenseFileUpload') }
    let(:rpc_request) { request_with }

    def request_with(filename: 'receipt.pdf', content_type: 'application/pdf')
      Rk::SponsorApp::SponsorServiceCreateExpenseFileUploadRequest.new(
        conference_slug: conference.slug,
        input: Rk::SponsorApp::ExpenseFileUploadInput.new(filename:, content_type:),
      )
    end

    it_behaves_like 'an RPC refused while the report is under review or approved'

    it 'records a pending file under the sponsorship and returns a presigned POST for it' do
      upload = connect_call(rpc, rpc_request).upload

      file = sponsorship.expense_files.sole
      expect(file).to have_attributes(
        filename: 'receipt.pdf', content_type: 'application/pdf', status: 'pending',
        prefix: "c-#{conference.id}/expenses/s-#{sponsorship.id}/",
      )
      expect_upload_for(upload, file, content_type: 'application/pdf')
    end

    it 'takes an upload before the report is started' do
      report.destroy!

      expect(connect_call(rpc, rpc_request).upload.file_id).to eq(sponsorship.expense_files.sole.id)
    end

    it 'answers invalid_argument for a content type the editor does not take' do
      expect(violations_of(connect_call(rpc, request_with(content_type: 'text/html')))).to eq([['input.contentType', 'STRING_IN']])
      expect(ExpenseFile.count).to eq(0)
    end

    it 'answers invalid_argument without a filename' do
      expect(violations_of(connect_call(rpc, request_with(filename: '')))).to eq([['input.filename', 'REQUIRED']])
    end
  end

  describe 'InitiateExpenseFileUpdate' do
    let(:rpc) { connect_method('SponsorService', 'InitiateExpenseFileUpdate') }
    let!(:file) { pending_file }
    let(:rpc_request) { request_with }

    def request_with(file_id: file.id, content_type: nil)
      Rk::SponsorApp::SponsorServiceInitiateExpenseFileUpdateRequest.new(conference_slug: conference.slug, file_id:, content_type:)
    end

    it_behaves_like 'an RPC refused while the report is under review or approved'

    it 'returns a presigned POST for the content type declared at creation' do
      expect_upload_for(connect_call(rpc, rpc_request).upload, file, content_type: 'application/pdf')
    end

    it 'pins the presigned POST to a content type given, storing none' do
      expect_upload_for(connect_call(rpc, request_with(content_type: 'image/png')).upload, file, content_type: 'image/png')
      expect(file.reload.content_type).to eq('application/pdf')
    end

    it 'answers not_found for a file of another sponsorship' do
      foreign = FactoryBot.create(:expense_file, sponsorship: other_sponsorship)

      expect(connect_call(rpc, request_with(file_id: foreign.id))).to have_attributes(status: 404, code: 'not_found')
    end
  end

  describe 'CompleteExpenseFileUpload' do
    let(:rpc) { connect_method('SponsorService', 'CompleteExpenseFileUpload') }
    let!(:file) { pending_file }
    let(:rpc_request) { request_with }

    def request_with(file_id: file.id, filename: nil, version_id: 'v1', extension: 'PNG')
      Rk::SponsorApp::SponsorServiceCompleteExpenseFileUploadRequest.new(
        conference_slug: conference.slug, file_id:, filename:, version_id:, extension:,
      )
    end

    it_behaves_like 'an RPC refused while the report is under review or approved'

    it 'marks the file uploaded, taking its version, checksum and content type from the storage' do
      response = connect_call(rpc, request_with(filename: 'scan.png'))

      expect(file.reload).to have_attributes(
        status: 'uploaded', filename: 'scan.png', extension: 'png', version_id: 'v2', checksum_sha256: 'c3Vt', content_type: 'image/png',
      )
      expect(response.file).to have_attributes(id: file.id, filename: 'scan.png', content_type: 'image/png')
      expect(s3_client.api_requests.map { it.fetch(:operation_name) }).to eq([:head_object])
    end

    it 'lists the file in the report once uploaded' do
      connect_call(rpc, rpc_request)

      get_report = connect_method('SponsorService', 'GetExpenseReport')
      result = connect_call(get_report, Rk::SponsorApp::SponsorServiceGetExpenseReportRequest.new(conference_slug: conference.slug))
      expect(result.report.files.map(&:id)).to eq([file.id])
    end

    it 'answers failed_precondition while the storage holds no upload' do
      s3_client.stub_responses(:head_object, 'NotFound')

      expect(connect_call(rpc, rpc_request)).to have_attributes(status: 400, code: 'failed_precondition')
      expect(file.reload.status).to eq('pending')
    end

    it 'answers the invalid-record problem when the storage recorded a content type the editor does not take' do
      s3_client.stub_responses(:head_object, head_object.merge(content_type: 'text/html'))

      expect(problem_type_of(connect_call(rpc, rpc_request))).to eq('invalid-record')
      expect(file.reload.status).to eq('pending')
    end

    it 'answers not_found for a file of another sponsorship' do
      foreign = FactoryBot.create(:expense_file, sponsorship: other_sponsorship, status: 'pending')

      expect(connect_call(rpc, request_with(file_id: foreign.id))).to have_attributes(status: 404, code: 'not_found')
      expect(foreign.reload.status).to eq('pending')
    end
  end

  describe 'DeleteExpenseFile' do
    let(:rpc) { connect_method('SponsorService', 'DeleteExpenseFile') }
    let!(:file) { FactoryBot.create(:expense_file, sponsorship:, prefix: "c-#{conference.id}/expenses/s-#{sponsorship.id}/") }
    let(:rpc_request) { request_with }

    def request_with(file_id: file.id)
      Rk::SponsorApp::SponsorServiceDeleteExpenseFileRequest.new(conference_slug: conference.slug, file_id:)
    end

    %w[submitted approved].each do |status|
      it "answers failed_precondition for a #{status} report, keeping the file" do
        report.update!(status:)

        expect(connect_call(rpc, rpc_request)).to have_attributes(status: 400, code: 'failed_precondition')
        expect(ExpenseFile.exists?(file.id)).to be(true)
      end
    end

    it 'deletes the file and its object, detaching it from line items' do
      key = file.object_key
      line_item = FactoryBot.create(:expense_line_item, expense_report: report)
      line_item.expense_line_item_files.create!(expense_file: file)

      connect_call(rpc, rpc_request)

      expect(ExpenseFile.exists?(file.id)).to be(false)
      expect(line_item.reload.expense_file_ids).to be_empty
      expect(s3_client.api_requests.sole).to include(operation_name: :delete_object, params: {bucket: 'dummy', key:})
    end

    it 'reopens a rejected report when the file was attached to a line item' do
      report.update!(status: 'rejected')
      FactoryBot.create(:expense_line_item, expense_report: report).expense_line_item_files.create!(expense_file: file)

      connect_call(rpc, rpc_request)

      expect(report.reload.status).to eq('draft')
    end

    it 'leaves a rejected report as it is when the file was attached to nothing' do
      report.update!(status: 'rejected')

      connect_call(rpc, rpc_request)

      expect(report.reload.status).to eq('rejected')
    end

    it 'deletes a file of a sponsorship without a report' do
      report.destroy!

      connect_call(rpc, rpc_request)

      expect(ExpenseFile.exists?(file.id)).to be(false)
    end

    it 'answers not_found for a file of another sponsorship' do
      foreign = FactoryBot.create(:expense_file, sponsorship: other_sponsorship)

      expect(connect_call(rpc, request_with(file_id: foreign.id))).to have_attributes(status: 404, code: 'not_found')
      expect(ExpenseFile.exists?(foreign.id)).to be(true)
    end

    it 'answers permission_denied to a sponsorship that is not custom' do
      sponsorship.update!(customization: false)

      expect(connect_call(rpc, rpc_request)).to have_attributes(status: 403, code: 'permission_denied')
      expect(ExpenseFile.exists?(file.id)).to be(true)
    end

    it 'answers unauthenticated without a sponsor session' do
      reset!

      expect(connect_call(rpc, rpc_request)).to have_attributes(status: 401, code: 'unauthenticated')
    end
  end
end
