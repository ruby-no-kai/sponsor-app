class AddTitoSlugToConferences < ActiveRecord::Migration[6.0]
  def change
    add_column :conferences, :tito_slug, :string, unique: true
  end
end
