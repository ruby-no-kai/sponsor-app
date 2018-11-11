class CreateSponsorshipEditingHistories < ActiveRecord::Migration[5.2]
  def change
    create_table :sponsorship_editing_histories do |t|
      t.references :sponsorship, foreign_key: true, null: false
      t.references :staff, foreign_key: true, null: true
      t.string :comment
      t.jsonb :diff, null: false
      t.jsonb :raw, null: false

      t.timestamps
    end

    add_index :sponsorship_editing_histories, [:sponsorship_id, :id]
  end
end
