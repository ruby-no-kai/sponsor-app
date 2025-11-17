class AddTitoBoothPaidFlatDiscountAmountToConferences < ActiveRecord::Migration[8.1]
  def change
    add_column :conferences, :tito_booth_paid_flat_discount_amount, :decimal, precision: 8, scale: 2, null: false, default: 0.0
  end
end
