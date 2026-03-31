# frozen_string_literal: true

class AddPriceColumnsToPlans < ActiveRecord::Migration[8.1]
  def change
    add_column :plans, :price, :decimal, precision: 12, scale: 2, default: 0, null: false
    add_column :plans, :price_booth, :decimal, precision: 12, scale: 2, default: 0, null: false
  end
end
