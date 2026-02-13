class AddGithubRepoImagesPathToConferences < ActiveRecord::Migration[8.1]
  def change
    add_column :conferences, :github_repo_images_path, :string
  end
end
