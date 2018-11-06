class AddIndexToContacts < ActiveRecord::Migration[5.2]
  def change
    add_index :contacts, [:email, :kind, :sponsorship_id]
  end
end
