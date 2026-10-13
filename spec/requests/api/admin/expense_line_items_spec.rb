# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AdminService expense line items', type: :request do
  let(:staff) { FactoryBot.create(:staff) }
  let(:restricted_staff) { FactoryBot.create(:staff, restricted_repos: ['ruby-no-kai/rubykaigi-admitted']) }
  let(:conference) { FactoryBot.create(:conference) }
  let(:plan) { FactoryBot.create(:plan, conference:) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:, customization: true) }
  let(:other_sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:, customization: true) }
  let!(:report) { FactoryBot.create(:expense_report, sponsorship:) }
  let!(:first) { FactoryBot.create(:expense_line_item, expense_report: report, title: 'First', amount: '1000', position: 1) }
  let!(:second) { FactoryBot.create(:expense_line_item, expense_report: report, title: 'Second', amount: '2000', position: 3) }
  let(:receipt) { FactoryBot.create(:expense_file, sponsorship:, filename: 'receipt.pdf') }
  let(:invoice) { FactoryBot.create(:expense_file, sponsorship:, filename: 'invoice.pdf') }

  def input(**fields)
    Rk::SponsorApp::ExpenseLineItemInput.new(
      title: 'Venue rental',
      notes: 'Hall A',
      amount: '5000',
      tax_rate: '0.1',
      tax_amount: '0',
      preliminal: true,
      **fields,
    )
  end

  # The same rules hold whichever line item RPC takes the input.
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

    it 'answers invalid_argument for an amount beyond the column' do
      expect(violations_of(connect_call(rpc, request_with(input(amount: '12345678901')))))
        .to eq([['input.amount', 'EXPENSE_LINE_ITEM_INPUT_AMOUNT_FORMAT']])
      expect(violations_of(connect_call(rpc, request_with(input(amount: '1.234')))))
        .to eq([['input.amount', 'EXPENSE_LINE_ITEM_INPUT_AMOUNT_FORMAT']])
    end

    it 'answers invalid_argument for a blank title' do
      expect(violations_of(connect_call(rpc, request_with(input(title: '  ')))))
        .to eq([['input.title', 'EXPENSE_LINE_ITEM_INPUT_TITLE_NOT_BLANK']])
    end

    it 'answers invalid_argument for a file listed twice' do
      expect(violations_of(connect_call(rpc, request_with(input(file_ids: [receipt.id, receipt.id])))))
        .to eq([['input.fileIds', 'REPEATED_UNIQUE']])
    end

    it 'answers the invalid-record problem on the tax rate for a rate not offered' do
      error = connect_call(rpc, request_with(input(tax_rate: '0.05')))

      expect(error).to have_attributes(status: 400, code: 'invalid_argument')
      expect(problem_type_of(error)).to eq('invalid-record')
      expect(violations_of(error)).to eq([['input.taxRate', 'INCLUSION']])
    end

    it 'answers not_found for a file of another sponsorship, changing nothing' do
      foreign = FactoryBot.create(:expense_file, sponsorship: other_sponsorship)

      expect(connect_call(rpc, request_with(input(file_ids: [receipt.id, foreign.id]))))
        .to have_attributes(status: 404, code: 'not_found')
      expect(report.line_items.reload.map(&:title)).to eq(['First', 'Second'])
      expect(ExpenseLineItemFile.count).to eq(0)
    end

    it 'answers failed_precondition for an approved report, changing nothing' do
      report.update!(status: 'approved')

      error = connect_call(rpc, request_with(input))

      expect(error).to have_attributes(status: 400, code: 'failed_precondition')
      expect(problem_type_of(error)).to eq('failed-precondition')
      expect(report.line_items.reload.map(&:title)).to eq(['First', 'Second'])
    end

    it 'answers not_found for a sponsorship without a report' do
      expect(connect_call(rpc, request_with(input, sponsorship_id: other_sponsorship.id)))
        .to have_attributes(status: 404, code: 'not_found')
    end

    it 'answers unauthenticated without a staff session, before judging the request' do
      reset!

      expect(connect_call(rpc, request_with(input(amount: '1,000')))).to have_attributes(status: 401, code: 'unauthenticated')
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_with(input))).to have_attributes(status: 403, code: 'permission_denied')
    end
  end

  before { sign_in_staff(staff) }

  describe 'CreateExpenseLineItem' do
    let(:rpc) { connect_method('AdminService', 'CreateExpenseLineItem') }

    def request_with(input, sponsorship_id: sponsorship.id)
      Rk::SponsorApp::AdminServiceCreateExpenseLineItemRequest.new(conference_slug: conference.slug, sponsorship_id:, input:)
    end

    it_behaves_like 'an input judged by its rules'

    it 'adds the line item last with its files, calculating its tax and the totals' do
      response = connect_call(rpc, request_with(input(amount: '5555', file_ids: [invoice.id, receipt.id])))

      created = report.line_items.reload.last
      expect(response.line_item).to eq(Rk::SponsorApp::ExpenseLineItem.new(
        id: created.id,
        title: 'Venue rental',
        notes: 'Hall A',
        amount: '5555.0',
        tax_rate: '0.1',
        tax_amount: '555.0',
        preliminal: true,
        position: 4,
        file_ids: [invoice.id, receipt.id],
      ))
      expect(response.report.line_items.map(&:id)).to eq([first.id, second.id, created.id])
      expect(response.report).to have_attributes(total_amount: '8555.0', total_tax_amount: '855.0')
      expect(report.reload).to have_attributes(total_amount: 8555, total_tax_amount: 855)
    end

    it 'takes every offered rate as the calculation spells it' do
      expect(connect_call(rpc, request_with(input(tax_rate: '0.08'))).line_item).to have_attributes(tax_rate: '0.08', tax_amount: '400.0')
      expect(connect_call(rpc, request_with(input(tax_rate: '0.0'))).line_item).to have_attributes(tax_rate: '0.0', tax_amount: '0.0')
      expect(connect_call(rpc, request_with(input(tax_rate: '0'))).line_item).to have_attributes(tax_rate: '0.0', tax_amount: '0.0')
    end

    it 'keeps the tax as entered without a rate' do
      response = connect_call(rpc, request_with(input(tax_rate: nil, tax_amount: '123.45', notes: nil)))

      expect(response.line_item).to have_attributes(has_tax_rate?: false, tax_amount: '123.45', has_notes?: false)
    end

    it 'puts the line item at the place given, renumbering the others' do
      response = connect_call(rpc, request_with(input(position: 2)))

      expect(response.report.line_items.map { [it.title, it.position] })
        .to eq([['First', 1], ['Venue rental', 2], ['Second', 3]])
    end

    it 'rewrites the snapshot under review while the report is submitted' do
      report.update!(status: 'submitted', revision: 1)
      submission = report.submissions.create!(revision: 1, data: report.build_snapshot_data)

      connect_call(rpc, request_with(input))

      expect(submission.reload.data.line_items.map(&:title)).to eq(['First', 'Second', 'Venue rental'])
      expect(submission.data.total_amount).to eq('8000.0')
    end

    it 'answers invalid_argument without an input' do
      expect(violations_of(connect_call(rpc, request_with(nil)))).to eq([['input', 'REQUIRED']])
    end

    it 'creates over binary protobuf, naming fields as it spells them' do
      expect(connect_call(rpc, request_with(input), codec: :proto).line_item.title).to eq('Venue rental')
      expect(violations_of(connect_call(rpc, request_with(input(tax_rate: '0.05')), codec: :proto)))
        .to eq([['input.tax_rate', 'INCLUSION']])
    end
  end

  describe 'UpdateExpenseLineItem' do
    let(:rpc) { connect_method('AdminService', 'UpdateExpenseLineItem') }

    def request_with(input, line_item_id: first.id, sponsorship_id: sponsorship.id)
      Rk::SponsorApp::AdminServiceUpdateExpenseLineItemRequest.new(
        conference_slug: conference.slug, sponsorship_id:, line_item_id:, input:,
      )
    end

    it_behaves_like 'an input judged by its rules'

    it 'replaces every field and the attached files, keeping attachments that stay' do
      first.expense_line_item_files.create!(expense_file: receipt)
      kept = first.expense_line_item_files.sole
      dropped = FactoryBot.create(:expense_file, sponsorship:)
      first.expense_line_item_files.create!(expense_file: dropped)

      response = connect_call(rpc, request_with(input(notes: nil, file_ids: [receipt.id, invoice.id])))

      expect(response.line_item).to eq(Rk::SponsorApp::ExpenseLineItem.new(
        id: first.id,
        title: 'Venue rental',
        amount: '5000.0',
        tax_rate: '0.1',
        tax_amount: '500.0',
        preliminal: true,
        position: 1,
        file_ids: [receipt.id, invoice.id],
      ))
      expect(first.reload.notes).to be_nil
      expect(first.expense_line_item_files.find_by(expense_file: receipt)).to eq(kept)
      expect(dropped.reload).to be_persisted
      expect(response.report).to have_attributes(total_amount: '7000.0')
    end

    it 'moves the line item to the place given' do
      third = FactoryBot.create(:expense_line_item, expense_report: report, title: 'Third', position: 7)

      response = connect_call(rpc, request_with(input(title: 'First', position: 3)))

      expect(response.report.line_items.map { [it.id, it.position] }).to eq([[second.id, 1], [third.id, 2], [first.id, 3]])
      expect(response.line_item.position).to eq(3)
    end

    it 'puts a line item given a place past the end last' do
      response = connect_call(rpc, request_with(input(position: 99)))

      expect(response.report.line_items.map(&:id)).to eq([second.id, first.id])
    end

    it 'leaves the positions alone without a place' do
      response = connect_call(rpc, request_with(input))

      expect(response.report.line_items.map(&:position)).to eq([1, 3])
    end

    it 'answers not_found for a line item of another sponsorship of the conference' do
      foreign = FactoryBot.create(:expense_line_item, expense_report: FactoryBot.create(:expense_report, sponsorship: other_sponsorship))

      expect(connect_call(rpc, request_with(input, line_item_id: foreign.id))).to have_attributes(status: 404, code: 'not_found')
      expect(foreign.reload.title).to eq('Test expense')
    end
  end

  describe 'DeleteExpenseLineItem' do
    let(:rpc) { connect_method('AdminService', 'DeleteExpenseLineItem') }

    def request_for(line_item_id = first.id, sponsorship_id: sponsorship.id)
      Rk::SponsorApp::AdminServiceDeleteExpenseLineItemRequest.new(conference_slug: conference.slug, sponsorship_id:, line_item_id:)
    end

    it 'deletes the line item, keeping its files, and recalculates the totals' do
      first.expense_line_item_files.create!(expense_file: receipt)

      response = connect_call(rpc, request_for)

      expect(response.report.line_items.map(&:id)).to eq([second.id])
      expect(response.report).to have_attributes(total_amount: '2000.0')
      expect(response.report.files.map(&:id)).to eq([receipt.id])
      expect(ExpenseLineItem.exists?(first.id)).to be(false)
    end

    it 'answers failed_precondition for an approved report' do
      report.update!(status: 'approved')

      expect(connect_call(rpc, request_for)).to have_attributes(status: 400, code: 'failed_precondition')
      expect(ExpenseLineItem.exists?(first.id)).to be(true)
    end

    it 'answers not_found for a line item of another sponsorship of the conference' do
      foreign = FactoryBot.create(:expense_line_item, expense_report: FactoryBot.create(:expense_report, sponsorship: other_sponsorship))

      expect(connect_call(rpc, request_for(foreign.id))).to have_attributes(status: 404, code: 'not_found')
      expect(ExpenseLineItem.exists?(foreign.id)).to be(true)
    end

    it 'answers not_found for a line item of the same sponsorship in another conference' do
      elsewhere = FactoryBot.create(:conference)
      expect(connect_call(rpc, Rk::SponsorApp::AdminServiceDeleteExpenseLineItemRequest.new(
        conference_slug: elsewhere.slug, sponsorship_id: sponsorship.id, line_item_id: first.id,
      ))).to have_attributes(status: 404, code: 'not_found')
      expect(ExpenseLineItem.exists?(first.id)).to be(true)
    end

    it 'answers unauthenticated without a staff session' do
      reset!

      expect(connect_call(rpc, request_for)).to have_attributes(status: 401, code: 'unauthenticated')
      expect(ExpenseLineItem.exists?(first.id)).to be(true)
    end

    it 'answers permission_denied to restricted staff for a conference they may not manage' do
      sign_in_staff(restricted_staff)

      expect(connect_call(rpc, request_for)).to have_attributes(status: 403, code: 'permission_denied')
      expect(ExpenseLineItem.exists?(first.id)).to be(true)
    end
  end
end
