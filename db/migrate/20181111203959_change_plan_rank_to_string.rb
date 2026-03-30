# frozen_string_literal: true

class ChangePlanRankToString < ActiveRecord::Migration[5.2]
  def up
    change_column :plans, :rank, :string,  null: true, default: nil
    change_column :plans, :rank, :integer, using: 'rank::integer', null: false, default: 0
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
