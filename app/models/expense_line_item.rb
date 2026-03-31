# frozen_string_literal: true

class ExpenseLineItem < ApplicationRecord
  belongs_to :expense_report
  has_many :expense_line_item_files, dependent: :destroy
  has_many :expense_files, through: :expense_line_item_files

  validates :title, presence: true
  validates :amount, numericality: {greater_than_or_equal_to: 0}
  validates :tax_amount, numericality: {greater_than_or_equal_to: 0}

  before_save :calculate_tax_amount

  def assign_next_position
    self.position = (expense_report.line_items.maximum(:position).to_i + 1)
  end

  private def calculate_tax_amount
    self.tax_amount = amount * tax_rate if tax_rate.present?
  end
end
