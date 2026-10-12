# typed: true
# frozen_string_literal: true

class ExpenseLineItem < ApplicationRecord
  belongs_to :expense_report
  has_many :expense_line_item_files, dependent: :destroy
  has_many :expense_files, through: :expense_line_item_files

  validates :title, presence: true
  validates :amount, numericality: {greater_than_or_equal_to: 0, less_than: 10_000_000_000}
  validates :tax_amount, numericality: {greater_than_or_equal_to: 0, less_than: 10_000_000_000}

  before_save :calculate_tax_amount

  def assign_next_position
    self.position = (Must.expect(expense_report).line_items.maximum(:position).to_i + 1)
  end

  private def calculate_tax_amount
    rate = tax_rate
    return if rate.nil?

    decimal = Rails.configuration.x.expense_report.decimal
    self.tax_amount = (amount * rate).floor(decimal)
  end
end
