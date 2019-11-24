class AddAcceptedAtToSponsorships < ActiveRecord::Migration[6.0]
  def change
    add_column :sponsorships, :accepted_at, :datetime

    Sponsorship.reset_column_information
    Sponsorship.find_in_batches do |batch|
      batch.each do |sponsorship|
        sponsorship.accepted_at ||= sponsorship.created_at
        sponsorship.save!
      end
    end
  end
end
