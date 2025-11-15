class AddFallbackOptions < ActiveRecord::Migration[8.1]
  def change
    add_column :form_descriptions, :fallback_options, :jsonb, null: false, default: {}
    add_column :sponsorships, :fallback_option, :string, null: false, default: ''
  end
end
