class AddWordsLimitToPlans < ActiveRecord::Migration[5.2]
  def change
    add_column :plans, :words_limit, :integer
  end
end
