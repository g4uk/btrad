Rails.application.load_tasks

class TradingJob
  def perform
    Rake::Task['trading:run'].execute
  end
end
