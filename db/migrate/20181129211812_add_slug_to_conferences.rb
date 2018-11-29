class AddSlugToConferences < ActiveRecord::Migration[5.2]
  def change
    add_column :conferences, :slug, :string
  end
end
