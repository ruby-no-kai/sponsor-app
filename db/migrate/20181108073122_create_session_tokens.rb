class CreateSessionTokens < ActiveRecord::Migration[5.2]
  def change
    create_table :session_tokens do |t|
      t.string :handle, null: false
      t.string :email
      t.references :sponsorship
      t.references :staff
      t.boolean :user_initiated, default: true
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :session_tokens, [:handle], unique: true
  end
end
