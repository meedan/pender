module Parser
  class TiktokItem < Base
    TIKTOK_ITEM_URL = /^https?:\/\/(www\.)?tiktok\.com\/(?<username>[^\/]+)\/video\/(?<id>[^\/|?]+)/

    class << self
      def type
        'tiktok_item'.freeze
      end

      def patterns
        [TIKTOK_ITEM_URL]
      end
    end

    def parse_data(doc)
      set_data_field('description', url)

      handle_exceptions(StandardError) do
        @parsed_data.merge!(get_tiktok_api_data(url))
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
    
    private
  
    def get_tiktok_api_data(requested_url)
      uri = URI.parse("https://www.tiktok.com/oembed?url=#{requested_url}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      headers = Media.extended_headers(uri)
      request = Net::HTTP::Get.new(uri.request_uri, headers)
      response = http.request(request)
      parsed_response = JSON.parse(response.body)
      {
        'raw' => {
          'oembed' => parsed_response,
          'api' => parsed_response,
        }
      }
    end
  end
end
