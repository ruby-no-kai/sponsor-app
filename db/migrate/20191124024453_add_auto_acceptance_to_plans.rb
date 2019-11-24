class AddAutoAcceptanceToPlans < ActiveRecord::Migration[6.0]
  def change
    add_column :plans, :auto_acceptance, :boolean, null: false, default: true
  end
end
