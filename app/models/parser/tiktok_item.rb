module Parser
  class TiktokItem < Base
    include ProviderTiktok

    TIKTOK_ITEM_URL = /^https?:\/\/(www\.)?tiktok\.com\/(?<username>[^\/]+)\/video\/(?<id>[^\/|?]+)/
    TIKTOK_TAG_URL = /^https?:\/\/(www\.)?tiktok\.com\/tag\/(?<tag>[^\/\?]+)/

    class << self
      def type
        'tiktok_item'.freeze
      end

      def patterns
        [TIKTOK_ITEM_URL, TIKTOK_TAG_URL]
      end
    end

    private

    # Main function for class
    def parse_data_for_parser(doc, _original_url, _jsonld_array)
      set_data_field('description', url)

      handle_exceptions(StandardError) do
        @parsed_data[:raw][:api] = @parsed_data[:raw][:oembed] = get_tiktok_api_data(url)
        if url.match(TIKTOK_ITEM_URL)
          match = url.match(TIKTOK_ITEM_URL)
          username = match['username']
          external_id = match['id']
          title = parsed_data['raw']['api']['title']
        elsif url.match(TIKTOK_TAG_URL)  
          username = ''
          external_id = ''
          title = "Tag: " + url.match(TIKTOK_TAG_URL)['tag']
        else
          username = ''
          external_id = ''
          title = parsed_data['raw']['api']['title']
        end

        @parsed_data.merge!({
          username: username,
          external_id: external_id,
          description: title,
          title: title,
          picture: parsed_data['raw']['api']['thumbnail_url'],
          author_url: parsed_data['raw']['api']['author_url'],
          html: parsed_data['raw']['api']['html'],
          author_name: parsed_data['raw']['api']['author_name']
        })
      end
      parsed_data
    end

    def get_tiktok_api_data(requested_url)
      uri = RequestHelper.parse_url(oembed_url)
      http = Net::HTTP.new(uri.host, uri.inferred_port)
      http.use_ssl = uri.scheme == 'https'
      headers = RequestHelper.extended_headers(uri)
      request = Net::HTTP::Get.new(uri.request_uri, headers)
      response = http.request(request)
      JSON.parse(response.body)
    end
  end
end
