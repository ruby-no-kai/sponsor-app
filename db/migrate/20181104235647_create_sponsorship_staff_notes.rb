class CreateSponsorshipStaffNotes < ActiveRecord::Migration[5.2]
  def change
    create_table :sponsorship_staff_notes do |t|
      t.references :sponsorship, null: false, foreign_key: true
      t.references :staff, null: false, foreign_key: true
      t.integer :stickiness, default: 0, null: false
      t.text :body, null: false

      t.timestamps
    end

    add_index :sponsorship_staff_notes, [:sponsorship_id, :stickiness, :created_at], name: :the_index
  end
end
