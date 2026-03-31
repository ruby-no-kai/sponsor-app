# frozen_string_literal: true

class ExpenseLineItemResource
  include Alba::Resource

  attributes :id, :title, :notes, :amount, :tax_rate, :tax_amount, :preliminal, :position

  attribute :file_ids, &:expense_file_ids
end
