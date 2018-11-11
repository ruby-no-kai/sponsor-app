class ChangePlanRankToString < ActiveRecord::Migration[5.2]
  def change
    change_column :plans, :rank, :string,  null: true, default: nil
    change_column :plans, :rank, :integer, using: 'rank::integer', null: false, default: 0
  end
end
