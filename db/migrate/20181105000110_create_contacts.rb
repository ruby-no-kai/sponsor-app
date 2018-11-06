class CreateContacts < ActiveRecord::Migration[5.2]
  def change
    create_table :contacts do |t|
      t.references :sponsorship, null: false, foreign_key: true
      t.integer :kind, null: false
      t.string :email, null: false
      t.string :address, null: false
      t.string :organization, null: false
      t.string :unit
      t.string :name, null: false

      t.timestamps
    end

    add_index :contacts, [:sponsorship_id, :kind], unique: true
  end
end
