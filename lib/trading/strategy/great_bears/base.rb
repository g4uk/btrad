require 'telegram/bot'

module Trading
  module Strategy::GreatBears
    class Base
      include Trading::TelegramMixin

      attr_accessor :long_stack, :trading_states, :exchange_driver, :currency, :base_currency, :balance_pair

      def initialize
        @latest_order = Order.where('status = ?', 'processed').order('id DESC').first

        @threshold_up = TradingState.where('name = ?', 'threshold_up').first.value.to_f
        @threshold_down = TradingState.where('name = ?', 'threshold_down').first.value.to_f

        @ignore_amount_profit = TradingState.where('name = ?', 'ignore_amount_trigger').first.value == 't'
      end

      def do
        @short_stack = long_stack.to_a.select{|sss| sss.rate_type == trading_type }.first(trading_states['max_analyze_iteration'].to_i)
        @newest_rate = @short_stack.first.dup
      end
    end
  end
end