class CreateSponsorEventAssetFiles < ActiveRecord::Migration[8.1]
  def change
    create_table :sponsor_event_asset_files do |t|
      t.references :sponsorship, foreign_key: true, null: false
      t.references :sponsor_event, foreign_key: true, index: false
      t.string :prefix, null: false
      t.string :handle, null: false
      t.string :extension
      t.string :version_id, null: false, default: ''
      t.string :checksum_sha256, null: false, default: ''
      t.datetime :last_modified_at

      t.timestamps
    end

    add_index :sponsor_event_asset_files, :handle
    add_index :sponsor_event_asset_files, :sponsor_event_id, unique: true
  end
end
