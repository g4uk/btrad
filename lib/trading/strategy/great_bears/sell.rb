module Trading
  module Strategy::GreatBears
    class Sell < Base
      def trading_type
        'sell'
      end

      def trading_type_for_profit
        'up'
      end

      def do
        super

        planning_rate_profit = @newest_rate.rate.to_f - trading_states['operation_rate'].to_f
        #count = (trading_states['base_currency_trade_limit'].to_f / @newest_rate.rate.to_f).to_i
        count = balance_pair[currency].to_i
        amount = @newest_rate.rate.to_f * count

        if amount <= 0
          say_telegram("Amount 0!")
          return nil
        end

        order_in_profit = (amount > @latest_order.amount * 1.02) || @ignore_amount_profit
        threshold_operation = false #@threshold_down.to_f > 0 && @threshold_down >= @newest_rate.rate.to_f && @newest_rate.change_type == 'down'

        if threshold_operation
          say_telegram("!!! Стоп-поріг НИЗ: #{@threshold_down}, Курс: #{@newest_rate.rate}. Втрати: #{planning_rate_profit * count}")
        end

        if (@newest_rate.change_type == trading_type_for_profit && planning_rate_profit > 0 && order_in_profit) || threshold_operation

          order = exchange_driver.sell(count, @newest_rate.rate.to_f, currency, base_currency)

          say_telegram("#{order}")
          say_telegram("Продаж #{count} #{currency} по #{@newest_rate.rate.to_f}. Профіт: #{planning_rate_profit * count} #{currency}")

          if order['status'] && order['order_id']
            operation_rate = @newest_rate.rate.to_f

            unless threshold_operation
              @threshold_up = planning_rate_profit*0.9 + @newest_rate.rate.to_f # стоп-поріг 90% від попереднього доходу для наступної операції
              TradingState.where('name = ?', 'threshold_up').update_all(value: @threshold_up.to_f)
            else
              TradingState.where('name = ?', 'threshold_up').update_all(value: false)
            end

            Order.create(
              order_id: order['order_id'],
              order_type: trading_type,
              status: :new,
              count: count,
              base_currency: base_currency,
              currency: currency,
              amount: amount,
              rate: @newest_rate.rate.to_f,
              profit: amount.to_f - @latest_order.amount.to_f
            )

            TradingState.where('name = ?', 'operation_rate').update_all(value: operation_rate.to_f)
            #TradingState.where('name = ?', 'base_currency_trade_limit').update_all(value: amount)
            #TradingState.where('name = ?', "btc_ua_#{@currency_pair}_trading_type").update_all(value: 'buy')

            if @ignore_amount_profit
              TradingState.where('name = ?', 'ignore_amount_trigger').update_all(value: false)
            end

            say_telegram("Створено угоду №#{order['order_id']}. Межа наступної операції: #{operation_rate}. Новий ліміт на торгівлю: #{amount}")
          else
            say_telegram("Не вдалось створити угоду: #{order}")
          end
        else
          _msg = []
          _msg << "валюта впала в ціні" if @newest_rate.change_type == 'down'
          _msg << "курс не змінився" if @newest_rate.change_type == 'none'
          _msg << "не вигідно продавати" if planning_rate_profit <= 0
          _msg << "підрахунки не відповідають очікуванням. amount: #{amount > @latest_order.amount * 1.01}" unless order_in_profit

          say_telegram("#{{planning_rate_profit: planning_rate_profit, change_type: @newest_rate.change_type, rate: @newest_rate.rate}}")
          say_telegram("#{_msg.join(' і ')}, чекаємо...")
        end
      end
    end
  end
end