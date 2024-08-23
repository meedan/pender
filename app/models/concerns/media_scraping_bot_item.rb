module MediaScrapingBotItem
  extend ActiveSupport::Concern

  class ScrapingBotError < StandardError; end
  class ScrapingBotResponseError < StandardError; end

  Media.class_eval do
    # Step 1: Send POST request to ScrapingBot to start scraping
    def self.scrapingbot_start_request(resource, url)
      scrapingbot_url = "https://api.scraping-bot.io/scrape/data-scraper"

      # Configure the POST request based on the resource (Facebook or Instagram)
      scraper_name = case resource
                     when :facebook_profile then "facebookProfile"
                     when :facebook_post then "facebookPost"
                     when :instagram_profile then "instagramProfile"
                     when :instagram_post then "instagramPost"
                     else
                       raise ScrapingBotError, "Unsupported resource: #{resource}"
                     end

      # Prepare the POST request
      headers = {
        'Accept' => 'application/json',
        'Authorization' => "Basic #{Base64.strict_encode64("#{ENV['SCRAPINGBOT_USERNAME']}:#{ENV['SCRAPINGBOT_API_KEY']}")}"
      }

      # POST request payload
      payload = {
        scraper: scraper_name,
        url: url
      }

      uri = URI.parse(scrapingbot_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(uri.request_uri, headers)
      request.body = payload.to_json

      begin
        response = http.request(request)
        Rails.logger.info level: 'INFO', message: '[Parser] Initiated scraping job on ScrapingBot', url: uri.to_s
        raise ScrapingBotResponseError if response.nil? || response.code != '200' || response.body.blank?

        result = JSON.parse(response.body)
        result['responseId']
      rescue ScrapingBotResponseError, JSON::ParserError => error
        PenderSentry.notify(
          ScrapingBotError.new(error),
          scrapingbot_url: uri,
          error_message: error.message,
          response_code: response&.code,
          response_body: response&.body
        )
        Rails.logger.warn level: 'WARN', message: '[Parser] Could not initiate ScrapingBot job', scrapingbot_url: uri, error_class: error.class, response_code: response&.code, response_body: response&.body
        nil
      end
    end

    # Step 2: Poll ScrapingBot for the scraping result
    def self.scrapingbot_get_result(resource, response_id)
      scrapingbot_url = "https://api.scraping-bot.io/scrape/data-scraper-response?scraper=#{resource}&responseId=#{response_id}"

      headers = {
        'Accept' => 'application/json',
        'Authorization' => "Basic #{Base64.strict_encode64("#{ENV['SCRAPINGBOT_USERNAME']}:#{ENV['SCRAPINGBOT_API_KEY']}")}"
      }

      uri = URI.parse(scrapingbot_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Get.new(uri.request_uri, headers)

      begin
        loop do
          response = http.request(request)
          Rails.logger.info level: 'INFO', message: '[Parser] Polling for ScrapingBot result', url: uri.to_s
          raise ScrapingBotResponseError if response.nil? || response.code != '200' || response.body.blank?

          result = JSON.parse(response.body)

          return result unless result['status'] == 'pending'

          # Sleep before polling again
          sleep 5
        end
      rescue ScrapingBotResponseError, JSON::ParserError => error
        PenderSentry.notify(
          ScrapingBotError.new(error),
          scrapingbot_url: uri,
          error_message: error.message,
          response_code: response&.code,
          response_body: response&.body
        )
        Rails.logger.warn level: 'WARN', message: '[Parser] Could not retrieve ScrapingBot result', scrapingbot_url: uri, error_class: error.class, response_code: response&.code, response_body: response&.body
        nil
      end
    end

    # Main method to handle the complete scraping process
    def self.scrapingbot_request(resource, url)
      response_id = scrapingbot_start_request(resource, url)
      return nil unless response_id

      scrapingbot_get_result(resource, response_id)
    end
  end
end
