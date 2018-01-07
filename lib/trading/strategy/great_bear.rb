module Trading
  class Strategy::GreatBear
    include Trading::TelegramMixin

    def initialize(currency_pair)
      @currency_pair = currency_pair.to_s
      @balance_pair = Hash[@currency_pair.split('_').map(&:upcase).zip [0, 0]]
      @base_currency = @currency_pair.split('_').map(&:upcase)[1]
      @currency = @currency_pair.split('_').map(&:upcase)[0]
    end

    def run(exchange_driver)
      say_telegram('Старт ітерації...')

      # >>>>>>>>>>>>>> перевірка відкритих заявок

      unless (open_orders = exchange_driver.my_orders['your_open_orders']).empty?
        open_orders.each do |oo|
          if Order.where('order_id = ?', oo['id'].to_i).first
            say_telegram('Є відкриті угоди. чекаємо...')
            return nil
          end
        end
      end

      say_telegram('Перевірка статусів ордерів...')
      Order.where(status: [:new, :processing]).all.each do |o|
        status = exchange_driver.order_status(o.order_id)
        if status['status'].present?
          _status = o.status.dup
          o.status = status['status']
          o.save!
          say_telegram("ордер #{o.order_id}: #{_status} -> #{o.status}")
        end
      end

      say_telegram('Перевірка балансу...')
      # >>>>>>>>>>>>>> перевірка балансу

      balance = exchange_driver.balance
      if !balance['accounts'].present? || balance['accounts'].empty?
        say_telegram('.відповідь на отримання балансу пуста')
        return nil
      end

      balance['accounts'].each do |a|
        if @balance_pair.key?(a['currency'])
          @balance_pair[a['currency']] = a['balance'].to_f
        end
      end

      say_telegram("Баланс: #{@balance_pair}")

      # >>>>>>>>>>>>>> визначення типу операції


      if TradingState.where('name = ?', "btc_ua_#{@currency_pair}_trading_type").first.value == 'f'
        if @balance_pair[@base_currency].to_f < trading_states['balance_minimum_for_trading'].to_f
          trading_type = 'sell'
        else
          trading_type = 'buy'
        end
        TradingState.where('name = ?', "btc_ua_#{@currency_pair}_trading_type").update_all(value: trading_type)
      else
        trading_type = TradingState.where('name = ?', "btc_ua_#{@currency_pair}_trading_type").first.value
      end

      say_telegram("Тип операції: #{trading_type}")

      # >>>>>>>>>>>>>> оновлення стеку курсів
      #
      # sell == bid, buy == ask

      rate = exchange_driver.bid(1)['cost_sum'].to_f
      if rate > 0.0
        last_sell_rate = RateStack.where(rate_type: :sell).order('created_at DESC').first

        sell_change_type = 'none' if last_sell_rate.nil? || last_sell_rate.rate.to_f == rate
        sell_change_type = 'up' if !last_sell_rate.nil? && last_sell_rate.rate.to_f < rate
        sell_change_type = 'down' if !last_sell_rate.nil? && last_sell_rate.rate.to_f > rate

        RateStack.create(base_currency: @base_currency, currency: @currency, rate_type: :sell, rate: rate, change_type: sell_change_type)
      end

      rate = exchange_driver.ask(1)['got_sum'].to_f
      if rate > 0.0
        last_buy_rate = RateStack.where(rate_type: :buy).order('created_at DESC').first

        buy_change_type = 'none' if last_buy_rate.nil? || last_buy_rate.rate.to_f == rate
        buy_change_type = 'up' if !last_buy_rate.nil? && last_buy_rate.rate.to_f < rate
        buy_change_type = 'down' if !last_buy_rate.nil? && last_buy_rate.rate.to_f > rate

        RateStack.create(base_currency: @base_currency, currency: @currency, rate_type: :buy, rate: rate, change_type: buy_change_type)
      end

      # >>>>>>>>>>>>>>>>>> побудова стеків
      #
      long_term_analyze_hours = Time.now - trading_states['long_term_analyze_hours'].to_i.hours
      long_stack = RateStack.where('created_at > ?', long_term_analyze_hours).order('created_at DESC').all.to_a

      # >>>>>>>>>>>>>>>>>

      if trading_states['operation_rate'].to_f == 0.0
        TradingState.where('name = ?', 'operation_rate').update_all(value: trading_type == 'sell' ? newest_rate_sell.rate.to_f : newest_rate_buy.rate.to_f)
      end

      strategy_action = "Trading::Strategy::GreatBears::#{trading_type.capitalize}".constantize.new
      strategy_action.exchange_driver = exchange_driver
      strategy_action.currency = @currency
      strategy_action.base_currency = @base_currency
      strategy_action.trading_states = trading_states
      strategy_action.long_stack = long_stack
      strategy_action.do
    end

    private

    def trading_states
      @trading_states ||= TradingState.all.to_a.inject({}) do |result, state|
        result.merge(state.name => state.value)
      end
    end
  end
end