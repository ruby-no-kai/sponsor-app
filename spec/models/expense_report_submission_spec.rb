# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExpenseReportSubmission, type: :model do
  let(:conference) { FactoryBot.create(:conference) }
  let(:plan) { FactoryBot.create(:plan, conference:) }
  let(:sponsorship) { FactoryBot.create(:sponsorship, conference:, plan:, customization: true) }
  let(:report) { FactoryBot.create(:expense_report, sponsorship:) }

  describe '#data' do
    let(:snapshot) do
      Rk::SponsorApp::Internal::ExpenseReportSnapshot.new(
        id: report.id,
        status: 'submitted',
        total_amount: '1500.0',
        total_tax_amount: '100.0',
        revision: 1,
        line_items: [
          Rk::SponsorApp::Internal::ExpenseReportSnapshot::LineItem.new(
            id: 11, title: 'Booth', amount: '1000.0', tax_rate: '0.1', tax_amount: '100.0', position: 1, file_ids: [21, 22],
          ),
          Rk::SponsorApp::Internal::ExpenseReportSnapshot::LineItem.new(
            id: 12, title: 'Novelty', notes: 'Exempt', amount: '500.0', tax_amount: '0.0', preliminal: true, position: 2,
          ),
        ],
      )
    end

    def stored_document(submission)
      JSON.parse(described_class.where(id: submission.id).pick(Arel.sql('data::text AS document')))
    end

    def store_document(submission, document)
      described_class.where(id: submission.id).update_all(['data = ?::jsonb', JSON.generate(document)]) # rubocop:disable Rails/SkipsModelValidations
    end

    it 'is an empty message by default' do
      expect(described_class.new.data).to eq(Rk::SponsorApp::Internal::ExpenseReportSnapshot.new)
    end

    it 'decodes an empty document as an empty message' do
      submission = FactoryBot.create(:expense_report_submission, expense_report: report)
      expect(submission.data).to eq(Rk::SponsorApp::Internal::ExpenseReportSnapshot.new)

      store_document(submission, {})
      expect(described_class.find(submission.id).data).to eq(Rk::SponsorApp::Internal::ExpenseReportSnapshot.new)
    end

    it 'round-trips the message through the column' do
      submission = FactoryBot.create(:expense_report_submission, expense_report: report, data: snapshot)

      expect(described_class.find(submission.id).data).to eq(snapshot)
    end

    it 'stores ProtoJSON in .proto field names, with defaults emitted and unset optional fields omitted' do
      submission = FactoryBot.create(:expense_report_submission, expense_report: report, data: snapshot)

      expect(stored_document(submission).fetch('line_items').last).to eq(
        'id' => '12',
        'title' => 'Novelty',
        'notes' => 'Exempt',
        'amount' => '500.0',
        'tax_amount' => '0.0',
        'preliminal' => true,
        'position' => 2,
        'file_ids' => [],
      )
    end

    it 'leaves a loaded record unchanged' do
      submission = FactoryBot.create(:expense_report_submission, expense_report: report, data: snapshot)

      expect(described_class.find(submission.id).changed?).to be(false)
    end

    it 'reads a row stored as a Hash, with explicit nulls and numeric ids' do
      submission = FactoryBot.create(:expense_report_submission, expense_report: report)
      store_document(submission, {
        id: report.id,
        status: 'submitted',
        total_amount: '500.0',
        total_tax_amount: '50.0',
        revision: 1,
        line_items: [
          {id: 11, title: 'Booth', notes: nil, amount: '500.0', tax_rate: nil, tax_amount: '50.0', preliminal: false, position: 1, file_ids: [21]},
        ],
      })

      data = described_class.find(submission.id).data
      expect(data).to have_attributes(id: report.id, total_amount: '500.0', revision: 1)
      expect(data.line_items.first).to have_attributes(id: 11, has_notes?: false, has_tax_rate?: false, tax_amount: '50.0')
      expect(data.line_items.first.file_ids.to_a).to eq([21])
    end

    it 'reads a document carrying a field the message does not declare' do
      submission = FactoryBot.create(:expense_report_submission, expense_report: report)
      store_document(submission, {revision: 2, retiredField: true})

      expect(described_class.find(submission.id).data.revision).to eq(2)
    end
  end

  describe '#reviewed?' do
    it 'returns false when no review exists' do
      submission = FactoryBot.create(:expense_report_submission, expense_report: report)
      expect(submission.reviewed?).to be false
    end

    it 'returns true when a review exists' do
      submission = FactoryBot.create(:expense_report_submission, expense_report: report)
      staff = FactoryBot.create(:staff)
      ExpenseReportReview.create_for!(submission, action: 'approve', comment: nil, staff:)
      expect(submission.reload.reviewed?).to be true
    end
  end
end
