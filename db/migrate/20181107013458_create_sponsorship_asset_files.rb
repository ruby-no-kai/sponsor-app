class CreateSponsorshipAssetFiles < ActiveRecord::Migration[5.2]
  def change
    create_table :sponsorship_asset_files do |t|
      t.references :sponsorship, foreign_key: true
      t.string :prefix, null: false
      t.string :handle, null: false
      t.string :extension

      t.timestamps
    end

    add_index :sponsorship_asset_files, [:handle]
    remove_column :sponsorships, :logo_key
  end
end
