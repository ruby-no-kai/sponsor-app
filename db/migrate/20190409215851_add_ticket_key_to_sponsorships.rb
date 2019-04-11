class AddTicketKeyToSponsorships < ActiveRecord::Migration[5.2]
  def change
    add_column :sponsorships, :ticket_key, :string

    Sponsorship.reset_column_information
    Sponsorship.find_each do |sponsorship|
      sponsorship.save! # validation assigns ticket_key
    end

    change_column_null :sponsorships, :ticket_key, false
    add_index :sponsorships, [:conference_id, :ticket_key], unique: true
  end
end
