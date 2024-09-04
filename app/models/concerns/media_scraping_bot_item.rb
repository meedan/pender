module MediaScrapingBotItem
  extend ActiveSupport::Concern

  class ScrapingBotError < StandardError; end
  class ScrapingBotResponseError < StandardError; end

  AUTH_KEY="Basic #{PenderConfig.get('scrapingbot_api_key')}"

  Media.class_eval do
    # Step 1: Send POST request to ScrapingBot to start scraping
    def self.scrapingbot_start_request(url)
      scrapingbot_url = "http://api.scraping-bot.io/scrape/data-scraper"

      # Prepare the POST request
      headers = {
        'content-type' => 'application/json',
        'authorization' => AUTH_KEY
      }

      # POST request payload
      payload = {
        scraper: "facebookPost",
        url: url
      }

      uri = URI.parse(scrapingbot_url)
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri.request_uri, headers)
      request.body = payload.to_json

      begin
        response = http.request(request)
        Rails.logger.info level: 'INFO', message: '[Parser] Initiated scraping job on ScrapingBot', url: uri.to_s
        raise ScrapingBotResponseError if response.nil? || !['200', '202'].include?(response.code) || response.body.blank?

        result = JSON.parse(response.body)
        result['responseId']
      rescue ScrapingBotResponseError, JSON::ParserError => error
        handle_scrapingbot_error(error, uri)
        nil
      end
    end

    # Step 2: Poll ScrapingBot for the scraping result
    def self.scrapingbot_get_result(response_id)
      scrapingbot_url = "http://api.scraping-bot.io/scrape/data-scraper-response?scraper=facebookPost&responseId=#{response_id}"

      headers = {
        'content-type' => 'application/json',
        'authorization' => AUTH_KEY
      }

      uri = URI.parse(scrapingbot_url)
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Get.new(uri.request_uri, headers)

      begin
        loop do
          response = http.request(request)
          Rails.logger.info level: 'INFO', message: '[Parser] Polling for ScrapingBot result', url: uri.to_s
          raise ScrapingBotResponseError if response.nil? || !['200', '202'].include?(response.code) || response.body.blank?

          result = JSON.parse(response.body)

          return result unless result['status'] == 'pending'

          # Sleep before polling again
          sleep 10
        end
      rescue ScrapingBotResponseError, JSON::ParserError => error
        handle_scrapingbot_error(error, uri)
        nil
      end
    end

    # Main method to handle the complete scraping process
    def self.scrapingbot_request( url)
      response_id = scrapingbot_start_request(url)
      return nil unless response_id

      scrapingbot_get_result(response_id)
    end

    def self.handle_scrapingbot_error(error, uri)
      PenderSentry.notify(
        ScrapingBotError.new(error),
        scrapingbot_url: uri,
        error_message: error.message
      )
      Rails.logger.warn level: 'WARN', message: '[Parser] Could not process ScrapingBot request', scrapingbot_url: uri, error_class: error.class
    end
  end
end
