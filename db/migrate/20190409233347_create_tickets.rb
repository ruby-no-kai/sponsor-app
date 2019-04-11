class CreateTickets < ActiveRecord::Migration[5.2]
  def change
    create_table :tickets do |t|
      t.references :conference, foreign_key: true, null: false
      t.references :sponsorship, foreign_key: true, null: false
      t.integer :kind, null: false
      t.string :code, null: false
      t.string :handle, null: false
      t.string :name, null: false
      t.string :email
      t.boolean :authorized, null: false, default: false
      t.datetime :checked_in_at

      t.timestamps
    end

    add_index :tickets, [:sponsorship_id, :kind, :checked_in_at]
    add_index :tickets, [:conference_id, :code], unique: true
    add_index :tickets, [:conference_id, :handle], unique: true
  end
end
