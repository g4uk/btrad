class CreateOrders < ActiveRecord::Migration[5.1]
  def change
    create_table :orders do |t|
      t.string :order_id, null: false, index: true
      t.string :order_type, null: false
      t.string :status, null: false, index: true
      t.integer :count
      t.string :base_currency, null: false
      t.string :currency, null: false
      t.float :amount, null: false, default: 0
      t.float :rate, null: false, default: 0
      t.timestamps
    end
  end
end
