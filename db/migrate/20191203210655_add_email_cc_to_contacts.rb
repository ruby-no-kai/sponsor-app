class AddEmailCcToContacts < ActiveRecord::Migration[6.0]
  def change
    add_column :contacts, :email_cc, :string
  end
end
