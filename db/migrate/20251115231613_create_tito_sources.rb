class CreateTitoSources < ActiveRecord::Migration[8.1]
  def change
    create_table :tito_sources do |t|
      t.bigint :conference_id, null: false
      t.bigint :sponsorship_id, null: true
      t.string :tito_source_id, null: false

      t.timestamps
    end
    add_index :tito_sources, [:conference_id]
    add_index :tito_sources, [:sponsorship_id], unique: true
    add_index :tito_sources, [:tito_source_id], unique: true
  end
end
