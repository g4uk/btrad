require 'telegram/bot'

module Trading
  module TelegramMixin
    def say_telegram(msg)
      if (chat_id = TradingState.where('name = ?', 'telegram_chat_id').first.value).present?
        Telegram::Bot::Api.new('473335262:AAGI5rNZHxzM2GijmI6rtCVJu0ZE0vKYi-8').send_message(chat_id: chat_id, text: msg)
      else
        Rails.logger.info(msg)
      end
    end
  end
end