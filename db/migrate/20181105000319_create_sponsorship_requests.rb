class CreateSponsorshipRequests < ActiveRecord::Migration[5.2]
  def change
    create_table :sponsorship_requests do |t|
      t.references :sponsorship, null: false
      t.integer :kind, null: false
      t.text :body, null: false

      t.timestamps
    end

    add_index :sponsorship_requests, [:sponsorship_id, :kind], unique: true
  end
end
