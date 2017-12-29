module Trading
  module TradingManager
    class Runner
      attr_accessor :exchange_driver

      def initialize(strategy)
        @strategy = strategy
      end

      def run
        @strategy.run(exchange_driver)
      end
    end
  end
end