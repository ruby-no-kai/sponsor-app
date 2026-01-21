class AddAffiliationCodeToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :affiliation_code, :string
    add_index :organizations, :affiliation_code, unique: true, where: 'affiliation_code IS NOT NULL'
  end
end
