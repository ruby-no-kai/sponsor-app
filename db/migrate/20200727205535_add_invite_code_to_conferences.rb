class AddInviteCodeToConferences < ActiveRecord::Migration[6.0]
  def change
    add_column :conferences, :invite_code, :string
  end
end
