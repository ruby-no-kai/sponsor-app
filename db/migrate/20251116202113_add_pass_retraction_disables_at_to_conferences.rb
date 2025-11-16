class AddPassRetractionDisablesAtToConferences < ActiveRecord::Migration[8.1]
  def change
    add_column :conferences, :pass_retraction_disables_at, :datetime
  end
end
