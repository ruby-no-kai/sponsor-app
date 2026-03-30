# frozen_string_literal: true

class AddReceptionKeyToConferences < ActiveRecord::Migration[5.2]
  def change
    add_column :conferences, :reception_key, :string

    Conference.reset_column_information
    Conference.find_each(&:save!) # validation assigns reception_key

    change_column_null :conferences, :reception_key, false
  end
end
