class CreateStaffs < ActiveRecord::Migration[5.2]
  def change
    create_table :staffs do |t|
      t.string :login, null: false
      t.string :name, null: false
      t.string :uid, null: false

      t.timestamps
    end

    add_index :staffs, [:uid], unique: true
    add_index :staffs, [:login], unique: true
  end
end
