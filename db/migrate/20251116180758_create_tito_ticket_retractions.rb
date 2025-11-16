class CreateTitoTicketRetractions < ActiveRecord::Migration[8.1]
  def change
    create_table :tito_ticket_retractions do |t|
      t.bigint :conference_id, null: false
      t.bigint :sponsorship_id, null: false
      t.boolean :completed, null: false, default: false
      t.text :reason, null: false
      t.string :tito_registration_id, null: false
      t.json :tito_registration, null: false
      t.json :tito_cancellation, null: true, default: nil

      t.timestamps
    end

    add_index :tito_ticket_retractions, :conference_id
    add_index :tito_ticket_retractions, :sponsorship_id
    add_index :tito_ticket_retractions, :tito_registration_id, unique: true
  end
end
