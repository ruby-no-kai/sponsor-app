# frozen_string_literal: true

class AddStatusToExpenseFiles < ActiveRecord::Migration[8.1]
  def up
    add_column :expense_files, :status, :string, null: false, default: 'pending'
    ExpenseFile.update_all(status: 'uploaded') # rubocop:disable Rails/SkipsModelValidations
  end

  def down
    remove_column :expense_files, :status
  end
end
