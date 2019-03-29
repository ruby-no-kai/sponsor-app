class CreateExhibitionEditingHistories < ActiveRecord::Migration[5.2]
  def change
    create_table :exhibition_editing_histories do |t|
      t.references :exhibition, foreign_key: true
      t.references :staff, foreign_key: true
      t.string :comment
      t.jsonb :diff
      t.jsonb :raw

      t.timestamps
    end

    add_index :exhibition_editing_histories, [:exhibition_id, :id]
  end
end
