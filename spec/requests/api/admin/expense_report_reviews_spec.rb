# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AdminService expense report reviews', type: :request do
  let(:rpc) { connect_method('AdminService', 'CreateExpenseReportReview') }
  let(:staff) { FactoryBot.create(:staff) }
  let(:restricted_staff) { FactoryBot.create(:staff, restricted_repos: ['ruby-no-kai/rubykaigi-admitted']) }
  let(:conference) { FactoryBot.create(:conference) }
  let(:plan) { FactoryBot.create(:plan, conference:) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:, customization: true) }
  let!(:report) { FactoryBot.create(:expense_report, sponsorship:, status: 'submitted', revision: 2) }
  let!(:submission) { FactoryBot.create(:expense_report_submission, expense_report: report, revision: 2) }

  def request_with(action:, comment: nil, sponsorship_id: sponsorship.id)
    Rk::SponsorApp::AdminServiceCreateExpenseReportReviewRequest.new(
      conference_slug: conference.slug,
      sponsorship_id:,
      input: Rk::SponsorApp::ExpenseReportReviewInput.new(action:, comment:),
    )
  end

  context 'with a staff session' do
    before { sign_in_staff(staff) }

    it 'approves the latest submission, signed by the staff member' do
      FactoryBot.create(:expense_report_submission, expense_report: report, revision: 1)

      response = connect_call(rpc, request_with(action: :ACTION_APPROVE))

      review = submission.reload.review
      expect(review).to have_attributes(action: 'approve', comment: nil, staff:)
      expect(response.report).to have_attributes(
        status: :STATUS_APPROVED,
        latest_review: Rk::SponsorApp::ExpenseReportReview.new(
          action: :ACTION_APPROVE,
          created_at: Google::Protobuf::Timestamp.from_time(review.created_at),
        ),
      )
      expect(report.reload.status).to eq('approved')
    end

    it 'rejects with a comment, replacing the verdict given before' do
      FactoryBot.create(:expense_report_review, expense_report_submission: submission, action: 'approve')
      report.update!(status: 'approved')

      response = connect_call(rpc, request_with(action: :ACTION_REJECT, comment: 'Add the venue invoice'))

      expect(response.report.status).to eq(:STATUS_REJECTED)
      expect(response.report.latest_review).to have_attributes(action: :ACTION_REJECT, comment: 'Add the venue invoice')
      expect(ExpenseReportReview.where(expense_report_submission: submission).count).to eq(1)
    end

    it 'answers the invalid-record problem on the comment for a rejection without one' do
      error = connect_call(rpc, request_with(action: :ACTION_REJECT, comment: ''))

      expect(error).to have_attributes(status: 400, code: 'invalid_argument')
      expect(problem_type_of(error)).to eq('invalid-record')
      expect(violations_of(error)).to eq([['input.comment', 'BLANK']])
      expect(report.reload.status).to eq('submitted')
      expect(submission.reload.review).to be_nil
    end

    it 'answers invalid_argument without a verdict' do
      error = connect_call(rpc, request_with(action: :ACTION_UNSPECIFIED))

      expect(violations_of(error)).to eq([['input.action', 'REQUIRED']])
    end

    it 'answers not_found for a report never submitted' do
      draft = FactoryBot.create(:expense_report, sponsorship: FactoryBot.create(:sponsorship, conference:, plan:, customization: true))

      error = connect_call(rpc, request_with(action: :ACTION_APPROVE, sponsorship_id: draft.sponsorship_id))

      expect(error).to have_attributes(status: 404, code: 'not_found')
      expect(draft.reload.status).to eq('draft')
    end

    it 'answers failed_precondition for a submission the sponsor withdrew' do
      report.withdraw_submission!

      expect(connect_call(rpc, request_with(action: :ACTION_APPROVE))).to have_attributes(status: 400, code: 'failed_precondition')
      expect(report.reload.status).to eq('draft')
      expect(submission.reload.review).to be_nil
    end

    it 'answers not_found for a sponsorship without a report' do
      bare = FactoryBot.create(:sponsorship, conference:, plan:, customization: true)

      expect(connect_call(rpc, request_with(action: :ACTION_APPROVE, sponsorship_id: bare.id)))
        .to have_attributes(status: 404, code: 'not_found')
    end

    it 'answers not_found for a sponsorship of another conference' do
      elsewhere = FactoryBot.create(:sponsorship, conference: FactoryBot.create(:conference), plan: nil, customization: true)
      FactoryBot.create(:expense_report_submission,
        expense_report: FactoryBot.create(:expense_report, sponsorship: elsewhere, status: 'submitted'))

      expect(connect_call(rpc, request_with(action: :ACTION_APPROVE, sponsorship_id: elsewhere.id)))
        .to have_attributes(status: 404, code: 'not_found')
      expect(elsewhere.expense_report.reload.status).to eq('submitted')
    end
  end

  it 'answers unauthenticated without a staff session, before judging the request' do
    expect(connect_call(rpc, request_with(action: :ACTION_UNSPECIFIED))).to have_attributes(status: 401, code: 'unauthenticated')
    expect(report.reload.status).to eq('submitted')
  end

  it 'answers permission_denied to restricted staff for a conference they may not manage' do
    sign_in_staff(restricted_staff)

    expect(connect_call(rpc, request_with(action: :ACTION_APPROVE))).to have_attributes(status: 403, code: 'permission_denied')
    expect(report.reload.status).to eq('submitted')
  end
end
