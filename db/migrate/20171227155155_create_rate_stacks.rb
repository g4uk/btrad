class CreateRateStacks < ActiveRecord::Migration[5.1]
  def change
    create_table :rate_stacks do |t|
      t.string :base_currency, null: false, index: true
      t.string :currency, null: false, index: true
      t.string :rate_type, null: false, index: true
      t.float :rate, null: false, default: 0
      t.string :change_type, null: false
      t.timestamps
    end
  end
end
