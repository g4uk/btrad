class CreateTradingStates < ActiveRecord::Migration[5.1]
  def change
    create_table :trading_states do |t|
      t.string :name, null: false, index: true
      t.text :value, null: true
      t.timestamps
    end
  end
end
