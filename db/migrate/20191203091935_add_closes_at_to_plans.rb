class AddClosesAtToPlans < ActiveRecord::Migration[6.0]
  def change
    add_column :plans, :closes_at, :datetime
  end
end
