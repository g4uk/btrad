require 'telegram/bot'

module Trading
  class Strategy::GreatBear

    TRAND_BY_TRADING_TYPE = {
      'sell' => 'up',
      'buy' => 'down'
    }

    MAGIC = {
      'sell' => 'buy',
      'buy' => 'sell'
    }

    MAX_THRESHOLD_COEF = 4

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
      long_stack = RateStack.where('created_at > ?', long_term_analyze_hours).order('created_at DESC').all.to_a

      short_stack_sell = long_stack.select{|sss| sss.rate_type == 'sell' }.first(trading_states['max_analyze_iteration'].to_i)
      short_stack_buy = long_stack.select{|ssb| ssb.rate_type == 'buy' }.first(trading_states['max_analyze_iteration'].to_i)

      newest_rate_sell = short_stack_sell.first.dup
      newest_rate_buy = short_stack_buy.first.dup

      trand_stack = long_stack.select{|ls| ls.change_type != 'none' }.first(MAX_THRESHOLD_COEF).map{|m| m.change_type}.group_by{|x| x}

      # >>>>>>>>>>>>>>>>>

      if trading_states['operation_rate'].to_f == 0.0
        TradingState.where('name = ?', 'operation_rate').update_all(value: trading_type == 'sell' ? newest_rate_sell.rate.to_f : newest_rate_buy.rate.to_f)
      end

      #cons = short_stack.map{|s| s.rate }.each_cons(2).collect { |a, b| b - a }
      #avg_short_rate_diff = cons.reduce(:+).to_f / cons.size
      avg_short_rate_diff = 0

      _threshold_iteration_count = TradingState.where('name = ?', 'threshold_iteration_count').first.value.to_i
      _threshold_operation = _threshold_iteration_count < MAX_THRESHOLD_COEF ? false : check_trand(trading_type, trand_stack)

      if trading_type == 'sell'
        planning_earnings = newest_rate_sell.rate.to_f - trading_states['operation_rate'].to_f
        if (newest_rate_sell.change_type == TRAND_BY_TRADING_TYPE[trading_type] && planning_earnings > avg_short_rate_diff) || _threshold_operation
          count = @balance_pair[@currency].to_i

          order = exchange_driver.sell(count, newest_rate_sell.rate.to_f, @currency, @base_currency)
          say_telegram("#{order}")

          say_telegram("Продаж #{@balance_pair[@currency]} #{@currency} по #{newest_rate_sell.rate.to_f}. Профіт: #{planning_earnings * count} #{@currency}")
          if order['status'] && order['order_id']

            _amount = newest_rate_sell.rate.to_f * count
            _operation_rate = newest_rate_sell.rate.to_f

            Order.create(
              order_id: order['order_id'],
              order_type: trading_type,
              status: :new,
              count: count,
              base_currency: @base_currency,
              currency: @currency,
              amount: _amount,
              rate: newest_rate_sell.rate.to_f
            )
            TradingState.where('name = ?', 'operation_rate').update_all(value: _operation_rate.to_f)
            TradingState.where('name = ?', 'threshold_iteration_count').update_all(value: 0)
ß
            say_telegram("Створено угоду №#{order['order_id']}. Межа наступної операції: #{_operation_rate}")
          else
            say_telegram("Не вдалось створити угоду: #{order}")
          end
        else
          TradingState.where('name = ?', 'threshold_iteration_count').update_all(value: _threshold_iteration_count += 1)

          _msg = []
          _msg << "валюта впала в ціні" if newest_rate_sell.change_type == 'down'
          _msg << "курс не змінився" if newest_rate_sell.change_type == 'none'
          _msg << "не вигідно продавати" if planning_earnings <= avg_short_rate_diff

          say_telegram("#{{planning_earnings: planning_earnings, avg_short_rate_diff: avg_short_rate_diff, change_type: newest_rate_sell.change_type, rate: newest_rate_sell.rate}}")
          say_telegram("#{_msg.join(' і ')}, чекаємо...")
        end
      else
        planning_earnings = trading_states['operation_rate'].to_f - newest_rate_buy.rate.to_f
        if (newest_rate_buy.change_type == TRAND_BY_TRADING_TYPE[trading_type] && planning_earnings > avg_short_rate_diff) || _threshold_operation
          count = (@balance_pair[@base_currency].to_f / newest_rate_buy.rate.to_f).to_i

          order = exchange_driver.buy(count, newest_rate_buy.rate.to_f, @currency, @base_currency)
          say_telegram("#{order}")

          say_telegram("Покупка #{@balance_pair[@currency]} #{@currency} по #{newest_rate_buy.rate.to_f}. Профіт: #{planning_earnings * count} #{@base_currency}")
          if order['status'] && order['order_id']

            _amount = newest_rate_buy.rate.to_f * count
            _operation_rate = newest_rate_buy.rate.to_f

            Order.create(
                order_id: order['order_id'],
                order_type: trading_type,
                status: :new,
                count: count,
                base_currency: @base_currency,
                currency: @currency,
                amount: _amount,
                rate: newest_rate_buy.rate.to_f
            )
            TradingState.where('name = ?', 'operation_rate').update_all(value: _operation_rate.to_f)
            TradingState.where('name = ?', 'threshold_iteration_count').update_all(value: 0)

            say_telegram("Створено угоду №#{order['order_id']}. Межа наступної операції (-1%): #{_operation_rate}")
          else
            say_telegram("Не вдалось створити угоду: #{order}")
          end
        else
          TradingState.where('name = ?', 'threshold_iteration_count').update_all(value: _threshold_iteration_count += 1)

          _msg = []
          _msg << "валюта виросла в ціні" if newest_rate_buy.change_type == 'up'
          _msg << "курс не змінився" if newest_rate_buy.change_type == 'none'
          _msg << "не вигідно купувати" if planning_earnings <= avg_short_rate_diff

          say_telegram("#{{planning_earnings: planning_earnings, avg_short_rate_diff: avg_short_rate_diff, change_type: newest_rate_buy.change_type, rate: newest_rate_buy.rate}}")
          say_telegram("#{_msg.join(' і ')}, чекаємо...")
        end
      end

    end

    #trand_stack = {"down"=>["down", "down", "down", "down", "down", "down"], "up"=>["up", "up", "up", "up", "up", "up", "up", "up", "up"]}
    def check_trand(trading_type, trand_stack)
      say_telegram("#{trading_type}: #{trand_stack[TRAND_BY_TRADING_TYPE[MAGIC[trading_type]]].to_a.count}")
      trand_stack[TRAND_BY_TRADING_TYPE[MAGIC[trading_type]]].to_a.count == MAX_THRESHOLD_COEF
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