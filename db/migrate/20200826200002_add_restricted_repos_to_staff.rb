class AddRestrictedReposToStaff < ActiveRecord::Migration[6.0]
  def change
    add_column :staffs, :restricted_repos, :string
  end
end
