module MediaCrowdtangleItem
  extend ActiveSupport::Concern

  class CrowdtangleError < StandardError; end
  class CrowdtangleResponseError < StandardError; end

  Media.class_eval do
    def self.crowdtangle_request(resource, id)
      # Cache to avoid hitting rate limits and to avoid making several requests to Crowdtangle during the same request life cycle
      Rails.cache.fetch("crowdtangle:request:#{resource}:#{id}", expires_in: 1.minute) do
        uri = RequestHelper.parse_url("https://api.crowdtangle.com/post/#{id}")

        http = Net::HTTP.new(uri.host, uri.inferred_port)
        http.use_ssl = true
        headers = { 'X-API-Token' => PenderConfig.get("crowdtangle_#{resource}_token") }
        request = Net::HTTP::Get.new(uri.request_uri, headers)

        begin
          response = http.request(request)
          Rails.logger.info level: 'INFO', message: '[Parser] Requesting data from Crowdtangle', url: uri.to_s
          raise CrowdtangleResponseError if response.nil? || response.code != '200' || response.body.blank?
          JSON.parse(response.body)
        rescue CrowdtangleResponseError, JSON::ParserError => error
          PenderSentry.notify(
            CrowdtangleError.new(error),
            crowdtangle_url: uri,
            error_message: error.message,
            response_code: response.code,
            response_body: response.body
          )
          Rails.logger.warn level: 'WARN', message: '[Parser] Could not get `crowdtangle` data', crowdtangle_url: uri, error_class: error.class, response_code: response.code, response_body: response.body
          {}
        end
      end
    end
  end
end
