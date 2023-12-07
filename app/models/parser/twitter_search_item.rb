module Parser
  class TwitterSearchItem < Base
    include ProviderTwitter

    TWITTER_SEARCH_ITEM_URL = /^https?:\/\/((0|m|mobile|www)\.)?twitter\.com\/search\?(?:[^&\s"]+&)*q=[^&\s"]+/

    class << self
      def type
        'twitter_search_item'.freeze
      end

      def patterns
        [TWITTER_SEARCH_ITEM_URL]
      end
    end

    private

    # Main function for class
    def parse_data_for_parser(_doc, _original_url, _jsonld_array)
      handle_exceptions(StandardError) do
        uri = RequestHelper.parse_url(url)
        params = uri.query.split('&').map { |pair| pair.split('=') }.to_h
        src = params['src']
        search_term = params['q']

        @parsed_data.merge!(
          title: search_term,
          search_term: search_term,
          src: src,
          description: uri,
          raw: {
            src: src
          }
        )
      end
      parsed_data
    end
  end
end