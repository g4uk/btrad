require 'telegram/bot'

module Trading
  module Strategy::GreatBears
    class Base
      include Trading::TelegramMixin

      attr_accessor :long_stack, :trading_states, :exchange_driver, :currency, :base_currency

      def initialize
        @latest_order = Order.order('id DESC').first

        @threshold_up = TradingState.where('name = ?', 'threshold_up').first.value.to_f
        @threshold_down = TradingState.where('name = ?', 'threshold_down').first.value.to_f

        @short_stack = long_stack.select{|sss| sss.rate_type == trading_type }.first(trading_states['max_analyze_iteration'].to_i)
        @newest_rate = @short_stack.first.dup

        @ignore_amount_profit = TradingState.where('name = ?', 'ignore_amount_trigger').first.value.to_i == 1
      end

      def do
        raise "`do` must be implemented"
      end
    end
  end
end