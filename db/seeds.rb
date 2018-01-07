# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

unless TradingState.where('name = ?', 'max_analyze_iteration').exists?
  TradingState.create(name: 'max_analyze_iteration', value: 7)
end

unless TradingState.where('name = ?', 'balance_minimum_for_trading').exists?
  TradingState.create(name: 'balance_minimum_for_trading', value: 0.01)
end

unless TradingState.where('name = ?', 'trating_enabled').exists?
  TradingState.create(name: 'trating_enabled', value: false)
end

unless TradingState.where('name = ?', 'telegram_chat_id').exists?
  TradingState.create(name: 'telegram_chat_id', value: nil)
end

unless TradingState.where('name = ?', 'long_term_analyze_hours').exists?
  TradingState.create(name: 'long_term_analyze_hours', value: 24)
end

unless TradingState.where('name = ?', 'operation_rate').exists?
  TradingState.create(name: 'operation_rate', value: 0.0)
end

unless TradingState.where('name = ?', 'base_currency_trade_limit').exists?
  TradingState.create(name: 'base_currency_trade_limit', value: 10)
end

unless TradingState.where('name = ?', 'threshold_up').exists?
  TradingState.create(name: 'threshold_up', value: false)
end

unless TradingState.where('name = ?', 'threshold_down').exists?
  TradingState.create(name: 'threshold_down', value: false)
end

unless TradingState.where('name = ?', 'ignore_amount_trigger').exists?
  TradingState.create(name: 'ignore_amount_trigger', value: true)
end