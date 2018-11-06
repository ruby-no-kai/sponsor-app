class CreateOrganizations < ActiveRecord::Migration[5.2]
  def change
    create_table :organizations do |t|
      t.string :name, null: false
      t.string :domain, null: false

      t.timestamps
    end

    add_index :organizations, [:domain], unique: true
  end
end
