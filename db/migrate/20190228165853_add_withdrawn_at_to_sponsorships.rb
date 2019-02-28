class AddWithdrawnAtToSponsorships < ActiveRecord::Migration[5.2]
  def change
    add_column :sponsorships, :withdrawn_at, :datetime
  end
end
