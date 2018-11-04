class CreateFormDescriptions < ActiveRecord::Migration[5.2]
  def change
    create_table :form_descriptions do |t|
      t.references :conference, foreign_key: true, null: false
      t.string :locale, null: false
      t.text :head
      t.text :head_html
      t.text :plan_help
      t.text :plan_help_html
      t.text :booth_help
      t.text :booth_help_html
      t.text :policy_help
      t.text :policy_help_html

      t.timestamps
    end

    add_index :form_descriptions, [:conference_id, :locale], unique: true
  end
end
