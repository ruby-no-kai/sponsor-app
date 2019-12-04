class AddRecipientCcToBroadcastDeliveries < ActiveRecord::Migration[6.0]
  def change
    add_column :broadcast_deliveries, :recipient_cc, :string
  end
end
