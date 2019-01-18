class CreateBroadcasts < ActiveRecord::Migration[5.2]
  def change
    create_table :broadcasts do |t|
      t.references :conference, foreign_key: true, null: false
      t.string :campaign, null: false
      t.text :description, null: false
      t.integer :status, null: false
      t.string :title, null: false
      t.text :body, null: false
      t.references :staff, foreign_key: true, null: false
      t.boolean :hidden, default: false, null: false
      t.datetime :dispatched_at

      t.timestamps
    end

    add_index :broadcasts, [:conference_id, :campaign], unique: true
    add_index :broadcasts, [:conference_id, :id]
  end
end
