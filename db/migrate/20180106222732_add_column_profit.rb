class AddColumnProfit < ActiveRecord::Migration[5.1]
  def change
    add_column :orders, :profit, :float, default: 0
  end
end
