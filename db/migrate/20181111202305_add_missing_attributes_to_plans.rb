class AddMissingAttributesToPlans < ActiveRecord::Migration[5.2]
  def change
    add_column :plans, :talkable, :boolean
    add_column :plans, :price_text, :string
  end
end
