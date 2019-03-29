class CreateExhibitions < ActiveRecord::Migration[5.2]
  def change
    create_table :exhibitions do |t|
      t.references :sponsorship, foreign_key: true, unique: true
      t.text :description

      t.timestamps
    end
  end
end
