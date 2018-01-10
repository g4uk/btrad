namespace :trading do
  desc 'Run trading!'
  task :run => :environment do
    Trading::Runner.new(trading_strategy: :great_bear, exchange_driver: :btc_trade, currency_pair: :dash_uah).run
  end
end
