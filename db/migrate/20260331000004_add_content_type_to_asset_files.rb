# frozen_string_literal: true

class AddContentTypeToAssetFiles < ActiveRecord::Migration[8.0]
  def change
    add_column :sponsorship_asset_files, :content_type, :string
    add_column :sponsor_event_asset_files, :content_type, :string
  end
end
