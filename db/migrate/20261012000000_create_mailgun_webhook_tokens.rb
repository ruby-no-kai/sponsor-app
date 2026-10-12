# frozen_string_literal: true

class CreateMailgunWebhookTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :mailgun_webhook_tokens do |t|
      t.string :token, null: false, index: {unique: true}
      t.datetime :signed_at, null: false, index: true

      t.timestamps
    end
  end
end
