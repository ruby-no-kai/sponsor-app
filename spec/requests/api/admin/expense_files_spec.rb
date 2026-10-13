# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AdminService expense files', type: :request do
  let(:staff) { FactoryBot.create(:staff) }
  let(:restricted_staff) { FactoryBot.create(:staff, restricted_repos: ['ruby-no-kai/rubykaigi-admitted']) }
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
    sign_in_staff(staff)
  end

  def pending_file(**attributes)
    ExpenseFile.prepare(conference:, sponsorship:).tap do |file|
      file.assign_attributes(filename: 'receipt.pdf', content_type: 'application/pdf', **attributes)
      file.save!
    end
  end

  # The presigned POST is pinned to the declared content type and to the object of the file.
  def expect_upload_for(upload, file, content_type:)
    expect(upload).to have_attributes(file_id: file.id, max_size: 20.megabytes)
    expect(upload.url).to start_with('https://')
    expect(upload.fields.to_h).to include('key' => file.object_key, 'Content-Type' => content_type)
  end

  shared_examples 'an RPC for staff who may manage the conference' do
    it 'answers unauthenticated without a staff session' do
      reset!

      expect(connect_call(rpc, rpc_request)).to have_attributes(status: 401, code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, rpc_request)).to have_attributes(status: 403, code: 'permission_denied')
    end
  end

  shared_examples 'an RPC refused once the report is approved' do
    it 'answers failed_precondition' do
      report.update!(status: 'approved')

      error = connect_call(rpc, rpc_request)

      expect(error).to have_attributes(status: 400, code: 'failed_precondition')
      expect(problem_type_of(error)).to eq('failed-precondition')
    end
  end

  describe 'CreateExpenseFileUpload' do
    let(:rpc) { connect_method('AdminService', 'CreateExpenseFileUpload') }
    let(:rpc_request) { request_with }

    def request_with(filename: 'receipt.pdf', content_type: 'application/pdf', sponsorship_id: sponsorship.id)
      Rk::SponsorApp::AdminServiceCreateExpenseFileUploadRequest.new(
        conference_slug: conference.slug,
        sponsorship_id:,
        input: Rk::SponsorApp::ExpenseFileUploadInput.new(filename:, content_type:),
      )
    end

    it_behaves_like 'an RPC refused once the report is approved'

    it 'records a pending file under the sponsorship and returns a presigned POST for it' do
      upload = connect_call(rpc, rpc_request).upload

      file = sponsorship.expense_files.sole
      expect(file).to have_attributes(
        filename: 'receipt.pdf',
        content_type: 'application/pdf',
        status: 'pending',
        prefix: "c-#{conference.id}/expenses/s-#{sponsorship.id}/",
      )
      expect_upload_for(upload, file, content_type: 'application/pdf')
    end

    it 'leaves a pending file out of the report' do
      connect_call(rpc, rpc_request)

      report_rpc = connect_method('AdminService', 'GetExpenseReport')
      expect(connect_call(report_rpc, Rk::SponsorApp::AdminServiceGetExpenseReportRequest.new(
        conference_slug: conference.slug, sponsorship_id: sponsorship.id,
      )).report.files).to be_empty
    end

    it 'answers invalid_argument for a content type the editor does not take' do
      expect(violations_of(connect_call(rpc, request_with(content_type: 'text/html')))).to eq([['input.contentType', 'STRING_IN']])
      expect(ExpenseFile.count).to eq(0)
    end

    it 'answers invalid_argument without a filename' do
      expect(violations_of(connect_call(rpc, request_with(filename: '')))).to eq([['input.filename', 'REQUIRED']])
    end

    it 'answers invalid_argument without an input' do
      rpc_request.clear_input

      expect(violations_of(connect_call(rpc, rpc_request))).to eq([['input', 'REQUIRED']])
    end

    it 'starts an upload over binary protobuf, naming fields as it spells them' do
      expect(connect_call(rpc, rpc_request, codec: :proto).upload.file_id).to eq(sponsorship.expense_files.sole.id)
      expect(violations_of(connect_call(rpc, request_with(content_type: 'text/html'), codec: :proto)))
        .to eq([['input.content_type', 'STRING_IN']])
    end

    it 'answers not_found for a sponsorship of another conference' do
      elsewhere = FactoryBot.create(:sponsorship, conference: FactoryBot.create(:conference), plan: nil)

      expect(connect_call(rpc, request_with(sponsorship_id: elsewhere.id))).to have_attributes(status: 404, code: 'not_found')
      expect(ExpenseFile.count).to eq(0)
    end

    it 'answers unauthenticated without a staff session, before judging the request' do
      reset!

      expect(connect_call(rpc, request_with(content_type: 'text/html'))).to have_attributes(status: 401, code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, rpc_request)).to have_attributes(status: 403, code: 'permission_denied')
      expect(ExpenseFile.count).to eq(0)
    end
  end

  describe 'InitiateExpenseFileUpdate' do
    let(:rpc) { connect_method('AdminService', 'InitiateExpenseFileUpdate') }
    let!(:file) { pending_file }
    let(:rpc_request) { request_with }

    def request_with(file_id: file.id, content_type: nil, sponsorship_id: sponsorship.id)
      Rk::SponsorApp::AdminServiceInitiateExpenseFileUpdateRequest.new(
        conference_slug: conference.slug, sponsorship_id:, file_id:, content_type:,
      )
    end

    it_behaves_like 'an RPC for staff who may manage the conference'
    it_behaves_like 'an RPC refused once the report is approved'

    it 'returns a presigned POST for the content type declared at creation' do
      expect_upload_for(connect_call(rpc, rpc_request).upload, file, content_type: 'application/pdf')
    end

    it 'pins the presigned POST to a content type given, storing none' do
      expect_upload_for(connect_call(rpc, request_with(content_type: 'image/png')).upload, file, content_type: 'image/png')
      expect(file.reload.content_type).to eq('application/pdf')
    end

    it 'answers not_found for a file of another sponsorship of the conference' do
      foreign = FactoryBot.create(:expense_file, sponsorship: other_sponsorship)

      expect(connect_call(rpc, request_with(file_id: foreign.id))).to have_attributes(status: 404, code: 'not_found')
    end
  end

  describe 'CompleteExpenseFileUpload' do
    let(:rpc) { connect_method('AdminService', 'CompleteExpenseFileUpload') }
    let!(:file) { pending_file }
    let(:rpc_request) { request_with }

    def request_with(file_id: file.id, filename: nil, version_id: 'v1', extension: 'PNG')
      Rk::SponsorApp::AdminServiceCompleteExpenseFileUploadRequest.new(
        conference_slug: conference.slug, sponsorship_id: sponsorship.id, file_id:, filename:, version_id:, extension:,
      )
    end

    it_behaves_like 'an RPC for staff who may manage the conference'
    it_behaves_like 'an RPC refused once the report is approved'

    it 'marks the file uploaded, taking its version, checksum and content type from the storage' do
      response = connect_call(rpc, request_with(filename: 'scan.png'))

      expect(file.reload).to have_attributes(
        status: 'uploaded',
        filename: 'scan.png',
        extension: 'png',
        version_id: 'v2',
        checksum_sha256: 'c3Vt',
        content_type: 'image/png',
        last_modified_at: head_object.fetch(:last_modified),
      )
      expect(response.file).to eq(Rk::SponsorApp::ExpenseFile.new(
        id: file.id,
        filename: 'scan.png',
        content_type: 'image/png',
        created_at: Google::Protobuf::Timestamp.from_time(file.created_at),
      ))
      expect(s3_client.api_requests.map { it.fetch(:operation_name) }).to eq([:head_object])
      expect(s3_client.api_requests.sole.fetch(:params)).to include(bucket: 'dummy', key: file.object_key, checksum_mode: 'enabled')
    end

    it 'keeps the name given at creation without one, and records an unknown extension for an empty one' do
      connect_call(rpc, request_with(extension: ''))

      expect(file.reload).to have_attributes(filename: 'receipt.pdf', extension: 'unknown')
    end

    it 'answers failed_precondition while the storage holds no upload' do
      s3_client.stub_responses(:head_object, 'NotFound')

      expect(connect_call(rpc, rpc_request)).to have_attributes(status: 400, code: 'failed_precondition')
      expect(file.reload.status).to eq('pending')
    end

    it 'answers the invalid-record problem when the storage recorded a content type the editor does not take' do
      s3_client.stub_responses(:head_object, head_object.merge(content_type: 'text/html'))

      error = connect_call(rpc, rpc_request)

      expect(problem_type_of(error)).to eq('invalid-record')
      expect(bad_request_of(error).field_violations.map(&:field)).to eq([''])
      expect(file.reload.status).to eq('pending')
    end

    it 'answers not_found for a file of another sponsorship of the conference' do
      foreign = FactoryBot.create(:expense_file, sponsorship: other_sponsorship, status: 'pending')

      expect(connect_call(rpc, request_with(file_id: foreign.id))).to have_attributes(status: 404, code: 'not_found')
      expect(foreign.reload.status).to eq('pending')
    end

    it 'answers invalid_argument for a filename given empty' do
      expect(violations_of(connect_call(rpc, request_with(filename: '')))).to eq([['filename', 'STRING_MIN_LEN']])
    end
  end

  describe 'DeleteExpenseFile' do
    let(:rpc) { connect_method('AdminService', 'DeleteExpenseFile') }
    let!(:file) { FactoryBot.create(:expense_file, sponsorship:, prefix: "c-#{conference.id}/expenses/s-#{sponsorship.id}/") }
    let(:rpc_request) { request_with }

    def request_with(file_id: file.id)
      Rk::SponsorApp::AdminServiceDeleteExpenseFileRequest.new(conference_slug: conference.slug, sponsorship_id: sponsorship.id, file_id:)
    end

    it_behaves_like 'an RPC refused once the report is approved'

    it 'deletes the file and its object, detaching it from line items' do
      key = file.object_key
      line_item = FactoryBot.create(:expense_line_item, expense_report: report)
      line_item.expense_line_item_files.create!(expense_file: file)

      connect_call(rpc, rpc_request)

      expect(ExpenseFile.exists?(file.id)).to be(false)
      expect(line_item.reload.expense_file_ids).to be_empty
      expect(s3_client.api_requests.sole).to include(operation_name: :delete_object, params: {bucket: 'dummy', key:})
    end

    it 'rewrites the snapshot under review while the report is submitted' do
      line_item = FactoryBot.create(:expense_line_item, expense_report: report)
      line_item.expense_line_item_files.create!(expense_file: file)
      report.update!(status: 'submitted', revision: 1)
      submission = report.submissions.create!(revision: 1, data: report.build_snapshot_data)

      connect_call(rpc, rpc_request)

      expect(submission.reload.data.line_items.sole.file_ids).to be_empty
    end

    it 'deletes a file of a sponsorship without a report' do
      report.destroy!

      connect_call(rpc, rpc_request)

      expect(ExpenseFile.exists?(file.id)).to be(false)
    end

    it 'answers not_found for a file of another sponsorship of the conference' do
      foreign = FactoryBot.create(:expense_file, sponsorship: other_sponsorship)

      expect(connect_call(rpc, request_with(file_id: foreign.id))).to have_attributes(status: 404, code: 'not_found')
      expect(ExpenseFile.exists?(foreign.id)).to be(true)
    end

    it 'answers unauthenticated without a staff session' do
      reset!

      expect(connect_call(rpc, rpc_request)).to have_attributes(status: 401, code: 'unauthenticated')
      expect(ExpenseFile.exists?(file.id)).to be(true)
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, rpc_request)).to have_attributes(status: 403, code: 'permission_denied')
      expect(ExpenseFile.exists?(file.id)).to be(true)
    end
  end
end
