module Parser
  class TiktokItem < Base
    include ProviderTiktok

    TIKTOK_ITEM_URL = /^https?:\/\/(www\.)?tiktok\.com\/(?<username>[^\/]+)\/video\/(?<id>[^\/|?]+)/

    class << self
      def type
        'tiktok_item'.freeze
      end

      def patterns
        [TIKTOK_ITEM_URL]
      end
    end

    private
    
    # Main function for class
    def parse_data_for_parser(doc, _ = nil)
      set_data_field('description', url)

      handle_exceptions(StandardError) do
        @parsed_data[:raw][:api] = @parsed_data[:raw][:oembed] = get_tiktok_api_data(url)
        match = url.match(TIKTOK_ITEM_URL)
        @parsed_data.merge!({
          username: match['username'],
          external_id: match['id'],
          description: parsed_data['raw']['api']['title'],
          title: parsed_data['raw']['api']['title'],
          picture: parsed_data['raw']['api']['thumbnail_url'],
          author_url: parsed_data['raw']['api']['author_url'],
          html: parsed_data['raw']['api']['html'],
          author_name: parsed_data['raw']['api']['author_name']
        })
      end
      parsed_data
    end
    
    def get_tiktok_api_data(requested_url)
      uri = URI.parse(oembed_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      headers = RequestHelper.extended_headers(uri)
      request = Net::HTTP::Get.new(uri.request_uri, headers)
      response = http.request(request)
      JSON.parse(response.body)
    end
  end
end
