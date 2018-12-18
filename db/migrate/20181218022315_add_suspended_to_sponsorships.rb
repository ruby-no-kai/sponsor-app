class AddSuspendedToSponsorships < ActiveRecord::Migration[5.2]
  def change
    add_column :sponsorships, :suspended, :boolean, null: false, default: false
  end
end
