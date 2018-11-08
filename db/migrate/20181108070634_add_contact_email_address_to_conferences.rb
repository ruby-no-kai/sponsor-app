class AddContactEmailAddressToConferences < ActiveRecord::Migration[5.2]
  def change
    add_column :conferences, :contact_email_address, :string
  end
end
