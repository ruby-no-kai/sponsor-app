class CreateTitoDiscountCodes < ActiveRecord::Migration[6.0]
  def change
    create_table :tito_discount_codes do |t|
      t.references :sponsorship, null: false, foreign_key: true
      t.integer :kind, null: false
      t.string :tito_discount_code_id, null: false, unique: true
      t.string :code, null: false
      t.integer :quantity, default: 0, null: false

      t.timestamps
    end

    add_index :tito_discount_codes, [:kind, :sponsorship_id], unique: true, name: 'kind_sponsorship'
  end
end
