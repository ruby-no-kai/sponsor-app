class AddGithubRepoToConferences < ActiveRecord::Migration[5.2]
  def change
    add_column :conferences, :github_repo, :string
  end
end
