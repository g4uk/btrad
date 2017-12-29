require 'rest_client'

module ExchangeDriver
  module HttpClient
    TIMEOUT = 3 # second

    def self.get(url, options={})
      request({ url: url, method: :get }.merge(options))
    end

    def self.delete(url, options={})
      request({ url: url, method: :delete }.merge(options))
    end

    def self.post(url, options={})
      request({ url: url, method: :post }.merge(options))
    end

    def self.put(url, options={})
      request({ url: url, method: :put }.merge(options))
    end

    def self.head(url, options={})
      request({ url: url, method: :head }.merge(options))
    end

    def self.request(options={})
      options = {
        open_timeout: TIMEOUT,
        timeout:      TIMEOUT
      }.merge(options)

      begin

        request  = RestClient::Request.new(options)
        response = request.execute
        parse_response(response, options)

      rescue *Errors::RestClient => e
        response = e.try(:response)
        Rails.logger.error [e.message, response.try(:to_str)].compact.join(" - ")
        parse_response(response, options)
      rescue ArgumentError => e
        Rails.logger.error "#{e.message} in #{options.inspect}"
        blank_response(options)
      end
    end

    module Errors
      RestClient = [
          RestClient::Unauthorized,
          RestClient::InternalServerError,
          RestClient::BadRequest
      ]
    end


    def self.parse_response(response, options)
      case (options[:headers]||{})[:accept]
        when :json
          JSON.parse(response.to_str)
        else
          response.to_str
      end
    end

    def self.blank_response(options)
      case options[:accept]
        when :json
          {}
        else
          ""
      end
    end

  end
end