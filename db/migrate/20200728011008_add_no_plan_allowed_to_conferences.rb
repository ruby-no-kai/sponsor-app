class AddNoPlanAllowedToConferences < ActiveRecord::Migration[6.0]
  def change
    add_column :conferences, :no_plan_allowed, :boolean, null: false, default: true
  end
end
