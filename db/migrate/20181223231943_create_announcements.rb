class CreateAnnouncements < ActiveRecord::Migration[5.2]
  def change
    create_table :announcements do |t|
      t.references :conference, foreign_key: true, null: false
      t.string :issue, null: false
      t.string :locale, null: false
      t.string :title, null: false
      t.text :body, null: false
      t.integer :stickiness, null: false, default: 0
      t.references :staff, foreign_key: true, null: false
      t.datetime :published_at
      t.integer :revision, null: false, default: 1
      t.timestamps
    end

    add_index :announcements, [:conference_id, :issue, :locale], unique: true
    add_index :announcements, [:conference_id, :issue, :id]
    add_index :announcements, [:conference_id, :locale, :stickiness, :id], name: :idx_user_listing
    add_index :announcements, [:conference_id, :issue, :revision]
  end
end
