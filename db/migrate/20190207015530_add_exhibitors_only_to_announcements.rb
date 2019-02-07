class AddExhibitorsOnlyToAnnouncements < ActiveRecord::Migration[5.2]
  def change
    add_column :announcements, :exhibitors_only, :boolean, null: false, default: false
  end
end
