class CreatePlans < ActiveRecord::Migration[5.2]
  def change
    create_table :plans do |t|
      t.references :conference, foreign_key: true, null: false
      t.string :name, null: false
      t.string :rank, default: 0, null: false
      t.string :summary
      t.integer :capacity, null: false
      t.integer :number_of_guests, default: 0, null: false
      t.integer :booth_size

      t.timestamps
    end

    add_index :plans, [:conference_id, :rank]
  end
end
