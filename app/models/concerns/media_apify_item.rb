module MediaApifyItem
  extend ActiveSupport::Concern

  class ApifyError < StandardError; end
  class ApifyResponseError < StandardError; end

  Media.class_eval do
    APIFY_URLS = {
      facebook: "https://api.apify.com/v2/acts/apify~facebook-posts-scraper/run-sync-get-dataset-items?token=#{PenderConfig.get('apify_api_token')}",
      instagram: "https://api.apify.com/v2/acts/apify~instagram-scraper/run-sync-get-dataset-items?token=#{PenderConfig.get('apify_api_token')}"
    }.freeze

    def self.apify_start_request(url, platform = :facebook)
      apify_url = APIFY_URLS[platform]
      raise ApifyError, 'Unsupported platform' unless apify_url

      headers = { 'content-type' => 'application/json' }

      payload = case platform
                when :facebook
                  {
                    resultsLimit: 20,
                    startUrls: [
                      { url: url }
                    ]
                  }
                when :instagram
                  {
                    addParentData: false,
                    directUrls: [url],
                    enhanceUserSearchWithFacebookPage: false,
                    isUserReelFeedURL: false,
                    isUserTaggedFeedURL: false,
                    resultsLimit: 200,
                    resultsType: "details",
                    searchLimit: 1,
                    searchType: "hashtag"
                  }
                else
                  raise ApifyError, 'Unsupported platform'
                end

      uri = URI.parse(apify_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(uri.request_uri, headers)
      request.body = payload.to_json

      begin
        response = http.request(request)

        Rails.logger.info level: 'INFO', message: "[Parser] Initiated scraping job on Apify (#{platform})", url: uri.to_s
        raise ApifyResponseError if response.nil? || !['200', '201'].include?(response.code) || response.body.blank?
        raise ApifyResponseError if response.body.include?("This content isn't available")

        JSON.parse(response.body)
      rescue ApifyResponseError, JSON::ParserError => error
        handle_apify_error(error, uri)
        nil
      end
    end

    def self.apify_request(url, platform = :facebook)
      response = apify_start_request(url, platform)
      return nil unless response

      response
    end

    def self.handle_apify_error(error, uri)
      PenderSentry.notify(
        ApifyError.new(error),
        apify_url: uri,
        error_message: error.message
      )
      Rails.logger.warn level: 'WARN', message: '[Parser] Could not process Apify request', apify_url: uri, error_class: error.class
    end
  end
end
