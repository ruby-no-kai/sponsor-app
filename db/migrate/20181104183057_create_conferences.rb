class CreateConferences < ActiveRecord::Migration[5.2]
  def change
    create_table :conferences do |t|
      t.string :name, null: false

      t.datetime :application_opens_at
      t.datetime :application_closes_at
      t.datetime :amendment_closes_at

      t.integer :booth_capacity, default: 0, null: false

      t.timestamps
    end

    add_index :conferences, :application_opens_at
  end
end
