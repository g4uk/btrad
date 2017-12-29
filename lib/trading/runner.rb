module Trading
  class Runner
    def initialize(opts)
      @trading_strategy = opts[:trading_strategy]
      @exchange_driver = opts[:exchange_driver]
      @currency_pair = opts[:currency_pair]
    end

    def run
      return nil if TradingState.where('name = ?', 'trating_enabled').first.value == 'f'

      strategy_engine = TradingManager::Runner.new( get_strategy )
      strategy_engine.exchange_driver = get_exchange_driver
      strategy_engine.run
    end

    private

    def get_strategy
      "Trading::Strategy::#{@trading_strategy.to_s.classify}".constantize.new(@currency_pair)
    end

    def get_exchange_driver
      "ExchangeDriver::#{@exchange_driver.to_s.classify}".constantize.new(@currency_pair)
    end
  end
end