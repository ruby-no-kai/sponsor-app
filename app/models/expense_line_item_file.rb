# frozen_string_literal: true

class ExpenseLineItemFile < ApplicationRecord
  belongs_to :expense_line_item
  belongs_to :expense_file

  validates :expense_file_id, uniqueness: {scope: :expense_line_item_id}
end
