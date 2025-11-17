class AddAutoAcceptanceDisabledToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :auto_acceptance_disabled, :boolean, null: false, default: false
  end
end
