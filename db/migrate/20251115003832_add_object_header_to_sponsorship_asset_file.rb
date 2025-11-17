class AddObjectHeaderToSponsorshipAssetFile < ActiveRecord::Migration[8.1]
  def change
    add_column :sponsorship_asset_files, :version_id, :string, default: '', null: false
    add_column :sponsorship_asset_files, :checksum_sha256, :string, default: '', null: false
    add_column :sponsorship_asset_files, :last_modified_at, :datetime
  end
end
