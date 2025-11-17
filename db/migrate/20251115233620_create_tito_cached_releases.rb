class CreateTitoCachedReleases < ActiveRecord::Migration[8.1]
  def change
    create_table :tito_cached_releases do |t|
      t.bigint :conference_id, null: false
      t.string :tito_release_slug, null: false
      t.string :tito_release_id, null: false

      t.timestamps
    end

    add_index :tito_cached_releases, [:conference_id, :tito_release_slug], unique: true
  end
end
