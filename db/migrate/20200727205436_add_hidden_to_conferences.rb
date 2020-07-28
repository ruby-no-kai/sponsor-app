class AddHiddenToConferences < ActiveRecord::Migration[6.0]
  def change
    add_column :conferences, :hidden, :boolean, null: false, default: false
  end
end
