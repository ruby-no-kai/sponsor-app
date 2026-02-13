class CreateSponsorEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :sponsor_events do |t|
      t.references :sponsorship, null: false, foreign_key: true
      t.references :conference, null: false, foreign_key: true
      t.string :slug, null: false
      t.string :title, null: false
      t.datetime :starts_at, null: false
      t.string :url, null: false
      t.string :price, null: false, default: ''
      t.string :capacity, null: false, default: ''
      t.string :location_en, null: false, default: ''
      t.string :location_local, null: false, default: ''
      t.integer :status, null: false, default: 0
      t.jsonb :co_host_sponsorship_ids, null: false, default: []
      t.string :link_name, null: false, default: ''
      t.text :admin_comment, null: false, default: ''
      t.datetime :policy_acknowledged_at

      t.timestamps
    end

    add_index :sponsor_events, [:sponsorship_id, :id]
    add_index :sponsor_events, [:conference_id, :slug], unique: true

    create_table :sponsor_event_editing_histories do |t|
      t.references :sponsor_event, foreign_key: true
      t.references :staff, foreign_key: true
      t.jsonb :raw
      t.jsonb :diff
      t.string :comment, null: false, default: ''

      t.timestamps
    end

    add_index :sponsor_event_editing_histories, [:sponsor_event_id, :id]

    add_column :conferences, :event_submission_starts_at, :datetime

    add_column :form_descriptions, :sponsor_event_help, :text, null: false, default: ''
    add_column :form_descriptions, :sponsor_event_help_html, :text, null: false, default: ''
    add_column :form_descriptions, :event_policy, :text, null: false, default: ''
    add_column :form_descriptions, :event_policy_html, :text, null: false, default: ''
  end
end
