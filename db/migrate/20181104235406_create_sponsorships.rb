class CreateSponsorships < ActiveRecord::Migration[5.2]
  def change
    create_table :sponsorships do |t|
      t.references :conference, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.references :plan, foreign_key: true
      t.string :locale, null: false

      t.boolean :customization, default: false, null: false
      t.string :customization_name

      t.string :name, null: false
      t.string :url, null: false
      t.text :profile, null: false
      t.string :logo_key

      t.boolean :booth_requested, default: false,  null: false
      t.boolean :booth_assigned, default: false, null: false

      t.timestamps
    end

    add_index :sponsorships, [:conference_id, :organization_id], unique: true
  end
end
