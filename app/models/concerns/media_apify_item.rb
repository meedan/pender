module MediaApifyItem
  extend ActiveSupport::Concern

  class ApifyError < StandardError; end
  class ApifyResponseError < StandardError; end

  Media.class_eval do
    APIFY_BASE_URL = "https://api.apify.com/v2/acts"
    APIFY_SUFFIX_URL = "/run-sync-get-dataset-items?token=#{PenderConfig.get('apify_api_token')}"

    SCRAPERS = {
      facebook: "apify~facebook-posts-scraper",
      instagram: "apify~instagram-scraper"
    }.freeze

    def self.apify_start_request(url, platform = :facebook)
      apify_url = build_apify_url(platform)
      raise ApifyError, 'Unsupported platform' unless apify_url

      payload = build_payload(url, platform)
      response = make_apify_request(apify_url, payload)

      handle_response(response, apify_url)
    end

    def self.build_apify_url(platform)
      scraper = SCRAPERS[platform]
      raise ApifyError, 'Unsupported platform' unless scraper

      "#{APIFY_BASE_URL}/#{scraper}#{APIFY_SUFFIX_URL}"
    end

    def self.build_payload(url, platform)
      case platform
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
    end

    def self.make_apify_request(apify_url, payload)
      uri = URI.parse(apify_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      headers = { 'content-type' => 'application/json' }
      request = Net::HTTP::Post.new(uri.request_uri, headers)
      request.body = payload.to_json

      http.request(request)
    end

    def self.handle_response(response, apify_url)
      Rails.logger.info level: 'INFO', message: '[Parser] Initiated scraping job on Apify', url: apify_url

      raise ApifyResponseError if response.nil? || !['200', '201'].include?(response.code) || response.body.blank?
      raise ApifyResponseError if response.body.include?("This content isn't available")

      JSON.parse(response.body)
    rescue ApifyResponseError, JSON::ParserError => error
      handle_apify_error(error, apify_url)
      nil
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
