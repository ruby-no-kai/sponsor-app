class AddSlugIndexToConferences < ActiveRecord::Migration[5.2]
  def change
    add_index :conferences, [:slug], unique: true
  end
end
