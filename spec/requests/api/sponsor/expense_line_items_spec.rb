# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SponsorService expense line items', type: :request do
  let(:conference) { FactoryBot.create(:conference) }
  let(:plan) { FactoryBot.create(:plan, conference:) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:, customization: true) }
  let(:other_sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:, customization: true) }
  let!(:report) { FactoryBot.create(:expense_report, sponsorship:) }
  let!(:first) { FactoryBot.create(:expense_line_item, expense_report: report, title: 'First', amount: '1000', position: 1) }
  let!(:second) { FactoryBot.create(:expense_line_item, expense_report: report, title: 'Second', amount: '2000', position: 3) }
  let(:receipt) { FactoryBot.create(:expense_file, sponsorship:, filename: 'receipt.pdf') }

  before { sign_in_sponsor(sponsorship.contact.email) }

  def input(**fields)
    Rk::SponsorApp::ExpenseLineItemInput.new(
      title: 'Venue rental', notes: 'Hall A', amount: '5000', tax_rate: '0.1', tax_amount: '0', preliminal: true, **fields,
    )
  end

  shared_examples 'an input judged by its rules' do
    it 'answers invalid_argument naming each malformed decimal' do
      error = connect_call(rpc, request_with(input(amount: '1,000', tax_rate: '10%', tax_amount: '-1')))

      expect(error).to have_attributes(status: 400, code: 'invalid_argument')
      expect(violations_of(error)).to contain_exactly(
        ['input.amount', 'EXPENSE_LINE_ITEM_INPUT_AMOUNT_FORMAT'],
        ['input.taxRate', 'EXPENSE_LINE_ITEM_INPUT_TAX_RATE_FORMAT'],
        ['input.taxAmount', 'EXPENSE_LINE_ITEM_INPUT_TAX_AMOUNT_FORMAT'],
      )
    end

    it 'answers the invalid-record problem on the tax rate for a rate not offered' do
      error = connect_call(rpc, request_with(input(tax_rate: '0.05')))

      expect(problem_type_of(error)).to eq('invalid-record')
      expect(violations_of(error)).to eq([['input.taxRate', 'INCLUSION']])
    end

    it 'answers not_found for a file of another sponsorship, changing nothing' do
      foreign = FactoryBot.create(:expense_file, sponsorship: other_sponsorship)

      expect(connect_call(rpc, request_with(input(file_ids: [receipt.id, foreign.id])))).to have_attributes(status: 404, code: 'not_found')
      expect(report.line_items.reload.map(&:title)).to eq(%w[First Second])
      expect(ExpenseLineItemFile.count).to eq(0)
    end

    %w[submitted approved].each do |status|
      it "answers failed_precondition for a #{status} report, changing nothing" do
        report.update!(status:)

        error = connect_call(rpc, request_with(input))

        expect(error).to have_attributes(status: 400, code: 'failed_precondition')
        expect(problem_type_of(error)).to eq('failed-precondition')
        expect(report.line_items.reload.map(&:title)).to eq(%w[First Second])
        expect(report.reload.status).to eq(status)
      end
    end

    it 'takes the change of a rejected report, reopening it as a draft' do
      report.update!(status: 'rejected')

      expect(connect_call(rpc, request_with(input)).report.status).to eq(:STATUS_DRAFT)
      expect(report.reload.status).to eq('draft')
    end

    it 'answers permission_denied to a sponsorship that is not custom' do
      sponsorship.update!(customization: false)

      expect(connect_call(rpc, request_with(input))).to have_attributes(status: 403, code: 'permission_denied')
    end

    it 'answers unauthenticated without a sponsor session, before judging the request' do
      reset!

      expect(connect_call(rpc, request_with(input(amount: '1,000')))).to have_attributes(status: 401, code: 'unauthenticated')
    end
  end

  describe 'CreateExpenseLineItem' do
    let(:rpc) { connect_method('SponsorService', 'CreateExpenseLineItem') }

    def request_with(input, slug: conference.slug)
      Rk::SponsorApp::SponsorServiceCreateExpenseLineItemRequest.new(conference_slug: slug, input:)
    end

    it_behaves_like 'an input judged by its rules'

    it 'adds the line item last with its files, calculating its tax and the totals' do
      response = connect_call(rpc, request_with(input(amount: '5555', file_ids: [receipt.id])))

      created = report.line_items.reload.last
      expect(response.line_item).to eq(Rk::SponsorApp::ExpenseLineItem.new(
        id: created.id, title: 'Venue rental', notes: 'Hall A', amount: '5555.0', tax_rate: '0.1', tax_amount: '555.0',
        preliminal: true, position: 4, file_ids: [receipt.id],
      ))
      expect(response.report.line_items.map(&:id)).to eq([first.id, second.id, created.id])
      expect(response.report).to have_attributes(total_amount: '8555.0', total_tax_amount: '855.0')
    end

    it 'puts the line item at the place given, renumbering the others' do
      response = connect_call(rpc, request_with(input(position: 2)))

      expect(response.report.line_items.map { [it.title, it.position] }).to eq([['First', 1], ['Venue rental', 2], ['Second', 3]])
    end

    it 'answers not_found for a report not started' do
      report.destroy!

      expect(connect_call(rpc, request_with(input))).to have_attributes(status: 404, code: 'not_found')
    end

    it 'answers invalid_argument without an input' do
      expect(violations_of(connect_call(rpc, request_with(nil)))).to eq([['input', 'REQUIRED']])
    end
  end

  describe 'UpdateExpenseLineItem' do
    let(:rpc) { connect_method('SponsorService', 'UpdateExpenseLineItem') }

    def request_with(input, line_item_id: first.id)
      Rk::SponsorApp::SponsorServiceUpdateExpenseLineItemRequest.new(conference_slug: conference.slug, line_item_id:, input:)
    end

    it_behaves_like 'an input judged by its rules'

    it 'replaces every field and the attached files' do
      first.expense_line_item_files.create!(expense_file: FactoryBot.create(:expense_file, sponsorship:))

      response = connect_call(rpc, request_with(input(notes: nil, file_ids: [receipt.id])))

      expect(response.line_item).to eq(Rk::SponsorApp::ExpenseLineItem.new(
        id: first.id, title: 'Venue rental', amount: '5000.0', tax_rate: '0.1', tax_amount: '500.0', preliminal: true, position: 1,
        file_ids: [receipt.id],
      ))
      expect(first.reload.notes).to be_nil
      expect(response.report).to have_attributes(total_amount: '7000.0')
    end

    it 'moves the line item to the place given' do
      response = connect_call(rpc, request_with(input(title: 'First', position: 2)))

      expect(response.report.line_items.map { [it.id, it.position] }).to eq([[second.id, 1], [first.id, 2]])
    end

    it 'rewrites no snapshot, as only a draft or rejected report takes changes' do
      report.update!(status: 'rejected', revision: 1)
      submission = report.submissions.create!(revision: 1, data: report.build_snapshot_data)

      connect_call(rpc, request_with(input))

      expect(submission.reload.data.line_items.map(&:title)).to eq(%w[First Second])
    end

    it 'answers not_found for a line item of another sponsorship' do
      foreign = FactoryBot.create(:expense_line_item, expense_report: FactoryBot.create(:expense_report, sponsorship: other_sponsorship))

      expect(connect_call(rpc, request_with(input, line_item_id: foreign.id))).to have_attributes(status: 404, code: 'not_found')
      expect(foreign.reload.title).to eq('Test expense')
    end
  end

  describe 'DeleteExpenseLineItem' do
    let(:rpc) { connect_method('SponsorService', 'DeleteExpenseLineItem') }

    def request_for(line_item_id = first.id)
      Rk::SponsorApp::SponsorServiceDeleteExpenseLineItemRequest.new(conference_slug: conference.slug, line_item_id:)
    end

    it 'deletes the line item, keeping its files, and recalculates the totals' do
      first.expense_line_item_files.create!(expense_file: receipt)

      response = connect_call(rpc, request_for)

      expect(response.report.line_items.map(&:id)).to eq([second.id])
      expect(response.report).to have_attributes(total_amount: '2000.0')
      expect(response.report.files.map(&:id)).to eq([receipt.id])
    end

    %w[submitted approved].each do |status|
      it "answers failed_precondition for a #{status} report" do
        report.update!(status:)

        expect(connect_call(rpc, request_for)).to have_attributes(status: 400, code: 'failed_precondition')
        expect(ExpenseLineItem.exists?(first.id)).to be(true)
      end
    end

    it 'takes the deletion from a rejected report, reopening it as a draft' do
      report.update!(status: 'rejected')

      expect(connect_call(rpc, request_for).report.status).to eq(:STATUS_DRAFT)
    end

    it 'answers not_found for a line item of another sponsorship' do
      foreign = FactoryBot.create(:expense_line_item, expense_report: FactoryBot.create(:expense_report, sponsorship: other_sponsorship))

      expect(connect_call(rpc, request_for(foreign.id))).to have_attributes(status: 404, code: 'not_found')
      expect(ExpenseLineItem.exists?(foreign.id)).to be(true)
    end
  end
end
