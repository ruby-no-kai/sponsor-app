# frozen_string_literal: true

class ExpenseReport < ApplicationRecord
  belongs_to :sponsorship
  has_many :line_items, -> { order(:position) }, class_name: 'ExpenseLineItem', inverse_of: :expense_report, dependent: :destroy
  has_many :submissions, class_name: 'ExpenseReportSubmission', dependent: :destroy

  validates :sponsorship_id, uniqueness: true
  validates :total_amount, numericality: {less_than: 10_000_000_000}, allow_nil: true
  validates :total_tax_amount, numericality: {less_than: 10_000_000_000}, allow_nil: true
  validate :validate_custom_sponsorship

  def recalculate_totals
    self.total_amount = line_items.sum(:amount)
    self.total_tax_amount = line_items.sum(:tax_amount)
  end

  def submit!
    raise "Cannot submit: status is #{status}" unless status == 'draft'

    transaction do
      self.revision += 1
      self.status = 'submitted'
      submissions.create!(revision:, data: build_snapshot_data)
      save!
    end
  end

  def withdraw_submission!
    raise "Cannot withdraw: status is #{status}" unless status == 'submitted'

    self.status = 'draft'
    save!
  end

  def reopen_if_rejected
    self.status = 'draft' if status == 'rejected'
  end

  def build_snapshot_data
    {
      id:,
      status:,
      total_amount: total_amount.to_s,
      total_tax_amount: total_tax_amount.to_s,
      revision:,
      line_items: line_items.order(:position).map do |li|
        {
          id: li.id,
          title: li.title,
          notes: li.notes,
          amount: li.amount.to_s,
          tax_rate: li.tax_rate&.to_s,
          tax_amount: li.tax_amount.to_s,
          preliminal: li.preliminal,
          position: li.position,
          file_ids: li.expense_file_ids,
        }
      end,
    }
  end

  def refresh_submission_snapshot
    return unless status == 'submitted'

    sub = current_submission
    return unless sub

    sub.update!(data: build_snapshot_data)
  end

  def current_submission
    submissions.order(revision: :desc).first
  end

  def latest_review
    current_submission&.review
  end

  private def validate_custom_sponsorship
    return unless sponsorship

    errors.add(:sponsorship, 'must be a custom sponsorship') unless sponsorship.customization
  end
end
