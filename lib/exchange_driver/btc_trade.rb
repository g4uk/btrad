module ExchangeDriver
  class BtcTrade
    include HttpClient

    CURRENCY_PAIRS = ['btc_uah', 'ltc_uah', 'nvc_uah', 'clr_uah', 'doge_uah', 'ltc_btc', 'drk_btc', 'nvc_btc', 'vtc_btc',
                      'clr_btc', 'ppc_btc', 'hiro_btc', 'ppc_ltc', 'drk_ltc', 'nvc_ltc', 'hiro_ltc', 'vtc_ltc']

    PUBLIC_KEY = 'c6bf8b44a7f0cea0f66118995bba93d4081b3b6a43da819afb8f9f660e5bfe62'
    PRIVATE_KEY = '3a82d9c9299f41a8504249b546b1840e0af063e5caa607842a838364f5708ddb'

    RESOURCE = 'https://btc-trade.com.ua/api'

    MAX_RETRY_COUNT = 3
    AUTH_PERIOD = 1.hour

    def initialize(currency_pair = 'doge_uah')
      @request_id = 1 # from db
      @currency_pair = currency_pair
      @auth_time = nil
    end

    def deals
      url = make_url("deals/#{@currency_pair}")

      params = make_params
      deals = HttpClient.post(url, {headers: get_private_api_headers(params), payload: params})

      return deals
    end

    # types: [buy, sell]
    def trades(type)
      url = make_url("trades/#{type}/#{@currency_pair}")

      params = make_params
      trades = HttpClient.post(url, {headers: get_private_api_headers(params), payload: params})

      return trades
    end

    def japan_stat
      url = make_url("japan_stat/high/#{@currency_pair}")

      params = make_params
      japan_stat = HttpClient.post(url, {headers: get_private_api_headers(params), payload: params})

      return japan_stat
    end

    # --- PRIVATE API

    def balance
      return false unless auth

      url = make_url('balance')
      params = make_params

      balance = HttpClient.post(url, {headers: get_private_api_headers(params), payload: params})
      return balance
    end

    # currency -> currency1
    def sell(count, price, currency, currency_1)
      return false unless auth

      url = make_url("sell/#{@currency_pair}")

      params = make_params({count: count, price: price.to_f, currency: currency, currency1: currency_1})
      sell = HttpClient.post(url, {headers: get_private_api_headers(params), payload: params})

      return sell
    end

    # currency -> currency1
    def buy(count, price, currency, currency_1)
      return false unless auth

      url = make_url("buy/#{@currency_pair}")

      params = make_params({count: count, price: price.to_f, currency: currency, currency1: currency_1})
      buy = HttpClient.post(url, {headers: get_private_api_headers(params), payload: params})

      return buy
    end

    def my_orders
      return false unless auth

      url = make_url("my_orders/#{@currency_pair}")

      params = make_params
      my_orders = HttpClient.post(url, {headers: get_private_api_headers(params), payload: params})

      return my_orders
    end

    def order_status(id)
      return false unless auth

      url = make_url("order/status/#{id}")

      params = make_params(id: id)
      order_status = HttpClient.post(url, {headers: get_private_api_headers(params), payload: params})

      return order_status
    end

    def order_remove(id)
      return false unless auth

      url = make_url("remove/order/#{id}")

      params = make_params(id: id)
      order_remove = HttpClient.post(url, {headers: get_private_api_headers(params), payload: params})

      return order_remove
    end

    def ask(amount)
      return false unless auth

      url = make_url("ask/#{@currency_pair}")
      retry_count = 0
      ask = {'status' => false}

      params = make_params({amount: amount})
      while !ask['status'] && retry_count < MAX_RETRY_COUNT
        ask = HttpClient.post(url, {headers: get_private_api_headers(params), payload: params})
        retry_count += 1
      end

      return ask
    end

    def bid(amount)
      return false unless auth

      url = make_url("bid/#{@currency_pair}")
      retry_count = 0
      bid = {'status' => false}

      params = make_params({amount: amount})
      while !bid['status'] && retry_count < MAX_RETRY_COUNT
        bid = HttpClient.post(url, {headers: get_private_api_headers(params), payload: params})
        retry_count += 1
      end

      return bid
    end

    private

    def auth
      return true unless auth_needed?

      url = make_url('auth')
      params = make_params
      auth = {'status' => false}
      retry_count = 0

      while !auth['status'] && retry_count < MAX_RETRY_COUNT
        auth = HttpClient.post(url, {headers: get_private_api_headers(params), payload: params})
        retry_count += 1
      end

      unless auth['status']
        say_telegram('BtcTrade->auth failed')
      else
        @auth_time = Time.now
      end

      return auth['status']
    end

    def auth_needed?
      Time.now.to_i >= (@auth_time.to_i + AUTH_PERIOD.to_i)
    end

    def make_url(query)
      increment_request_id!
      "#{RESOURCE}/#{query}"
    end

    def get_private_api_headers(params = {})
      {
          'api-sign' => make_api_sign(params),
          'public-key' => PUBLIC_KEY,
          'Content-Type' => 'application/x-www-form-urlencoded',
          accept: :json
      }
    end

    def make_api_sign(params = {})
      Digest::SHA256.new.hexdigest("#{to_param(params)}#{PRIVATE_KEY}")
    end

    def make_required_params
      {out_order_id: @request_id, nonce: @request_id}
    end

    def make_params(params = {})
      Hash[make_required_params.merge(params).sort]
    end

    def increment_request_id!
      @request_id += 1
    end

    def to_param(params)
      str = []
      params.each_pair {|k,v| str << "#{k}=#{v}" }
      return str.join('&')
    end

    def say_telegram(msg)

    end
  end
end
