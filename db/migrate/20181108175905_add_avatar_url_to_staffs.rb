class AddAvatarUrlToStaffs < ActiveRecord::Migration[5.2]
  def change
    add_column :staffs, :avatar_url, :string
  end
end
