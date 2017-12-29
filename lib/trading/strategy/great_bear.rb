require 'telegram/bot'

module Trading
  class Strategy::GreatBear

    def initialize(currency_pair)
      @currency_pair = currency_pair.to_s
      @balance_pair = Hash[@currency_pair.split('_').map(&:upcase).zip [0, 0]]
      @base_currency = @currency_pair.split('_').map(&:upcase)[1]
      @currency = @currency_pair.split('_').map(&:upcase)[0]
    end

    def run(exchange_driver)
      say_telegram('Старт ітерації...')

      # >>>>>>>>>>>>>> перевірка відкритих заявок

      unless exchange_driver.my_orders['your_open_orders'].empty?
        say_telegram('Є відкриті угоди. чекаємо...')
        return nil
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

      if @balance_pair[@base_currency].to_f < trading_states['balance_minimum_for_trading'].to_f
        trading_type = 'sell'
      else
        trading_type = 'buy'
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
      long_stack = RateStack.where('rate_type = ? AND created_at > ?', trading_type, long_term_analyze_hours).order('created_at DESC').all.to_a

      short_stack = long_stack.first(trading_states['max_analyze_iteration'].to_i)
      newest_rate = short_stack.first.dup

      # >>>>>>>>>>>>>>>>>

      if trading_states['operation_rate'].to_f == 0.0
        TradingState.where('name = ?', 'operation_rate').update_all(value: newest_rate.rate.to_f)
      end

      cons = short_stack.map{|s| s.rate }.each_cons(2).collect { |a, b| b - a }
      avg_short_rate_diff = cons.reduce(:+).to_f / cons.size

      if trading_type == 'sell'
        planning_earnings = newest_rate.rate.to_f - trading_states['operation_rate'].to_f
        if newest_rate.change_type == 'up' && planning_earnings > avg_short_rate_diff
          count = @balance_pair[@currency].to_f

          order = exchange_driver.sell(count, newest_rate.rate.to_f, @currency, @base_currency)

          say_telegram("Продаж #{@balance_pair[@currency]} #{@currency} по #{newest_rate.rate.to_f}. Профіт: #{planning_earnings * count} #{@currency}")
          if order['status'] && order['order_id']
            Order.create(
              order_id: order['order_id'],
              order_type: trading_type,
              status: :new,
              count: count,
              base_currency: @base_currency,
              currency: @currency,
              amount: newest_rate.rate.to_f * count,
              rate: newest_rate.rate.to_f
            )
            TradingState.where('name = ?', 'operation_rate').update_all(value: newest_rate.rate.to_f)

            say_telegram("Створено угоду №#{order['order_id']}")
          else
            say_telegram("Не вдалось створити угоду: #{order}")
          end
        else
          _msg = []
          _msg << "валюта впала в ціні" if newest_rate.change_type == 'down'
          _msg << "курс не змінився" if newest_rate.change_type == 'none'
          _msg << "не вигідно продавати" if planning_earnings <= avg_short_rate_diff

          say_telegram("#{{planning_earnings: planning_earnings, avg_short_rate_diff: avg_short_rate_diff, change_type: newest_rate.change_type, rate: newest_rate.rate}}")
          say_telegram("#{_msg.join(' і ')}, чекаємо...")
        end
      else
        planning_earnings = trading_states['operation_rate'].to_f - newest_rate.rate.to_f
        if newest_rate.change_type == 'down' && planning_earnings > avg_short_rate_diff
          count = @balance_pair[@base_currency].to_f * newest_rate.rate.to_f

          order = exchange_driver.buy(count, newest_rate.rate.to_f, @currency, @base_currency)

          say_telegram("Покупка #{@balance_pair[@currency]} #{@currency} по #{newest_rate.rate.to_f}. Профіт: #{planning_earnings * count} #{@base_currency}")
          if order['status'] && order['order_id']
            Order.create(
                order_id: order['order_id'],
                order_type: trading_type,
                status: :new,
                count: count,
                base_currency: @base_currency,
                currency: @currency,
                amount: newest_rate.rate.to_f * count,
                rate: newest_rate.rate.to_f
            )
            TradingState.where('name = ?', 'operation_rate').update_all(value: newest_rate.rate.to_f)

            say_telegram("Створено угоду №#{order['order_id']}")
          else
            say_telegram("Не вдалось створити угоду: #{order}")
          end
        else
          _msg = []
          _msg << "валюта виросла в ціні" if newest_rate.change_type == 'up'
          _msg << "курс не змінився" if newest_rate.change_type == 'none'
          _msg << "не вигідно купувати" if planning_earnings <= avg_short_rate_diff

          say_telegram("#{{planning_earnings: planning_earnings, avg_short_rate_diff: avg_short_rate_diff, change_type: newest_rate.change_type, rate: newest_rate.rate}}")
          say_telegram("#{_msg.join(' і ')}, чекаємо...")
        end
      end

    end

    private

    def say_telegram(msg)
      if (chat_id = TradingState.where('name = ?', 'telegram_chat_id').first.value).present?
        Telegram::Bot::Api.new('473335262:AAGI5rNZHxzM2GijmI6rtCVJu0ZE0vKYi-8').send_message(chat_id: chat_id, text: msg)
      else
        Rails.logger.info(msg)
      end
    end

    def trading_states
      @trading_states ||= TradingState.all.to_a.inject({}) do |result, state|
        result.merge(state.name => state.value)
      end
    end
  end
end