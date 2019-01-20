class AddNumberOfAdditionalAttendeesToSponsorships < ActiveRecord::Migration[5.2]
  def change
    add_column :conferences, :additional_attendees_registration_open, :boolean, default: false, null: false
    add_column :sponsorships, :number_of_additional_attendees, :integer
    add_column :form_descriptions, :ticket_help, :text
    add_column :form_descriptions, :ticket_help_html, :text
  end
end
