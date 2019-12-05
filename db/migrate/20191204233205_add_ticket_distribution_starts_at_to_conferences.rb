class AddTicketDistributionStartsAtToConferences < ActiveRecord::Migration[6.0]
  def change
    add_column :conferences, :ticket_distribution_starts_at, :datetime
  end
end
