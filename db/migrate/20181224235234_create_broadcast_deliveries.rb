class CreateBroadcastDeliveries < ActiveRecord::Migration[5.2]
  def change
    create_table :broadcast_deliveries do |t|
      t.references :broadcast, foreign_key: true, null: false
      t.references :sponsorship, foreign_key: true
      t.string :recipient, null: false
      t.integer :status, null: false
      t.jsonb :meta

      t.datetime :dispatched_at
      t.datetime :opened_at

      t.timestamps
    end

    add_index :broadcast_deliveries, [:broadcast_id, :status]
    add_index :broadcast_deliveries, [:broadcast_id, :id]
    add_index :broadcast_deliveries, [:recipient]
  end
end
