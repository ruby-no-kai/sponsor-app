class AddAllowRestrictedAccessToConference < ActiveRecord::Migration[6.0]
  def change
    add_column :conferences, :allow_restricted_access, :boolean
  end
end
