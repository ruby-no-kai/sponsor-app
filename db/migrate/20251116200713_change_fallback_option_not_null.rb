# frozen_string_literal: true

class ChangeFallbackOptionNotNull < ActiveRecord::Migration[8.1]
  def change
    change_column_default :sponsorships, :fallback_option, from: nil, to: ''
    change_column_null :sponsorships, :fallback_option, false
  end
end
