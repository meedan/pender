module Parser
  class TwitterSearchItem < Base
    include ProviderTwitter

    TWITTER_SEARCH_ITEM_URL = /https:\/\/twitter\.com\/search[^\s"]*/

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
        params = URI.parse(url).query.split('&').map { |pair| pair.split('=') }.to_h
        src = params['src']
        search_term = params['q']

        @parsed_data.merge!(
          title: search_term,
          search_term: search_term,
          src: src,
          description: "Twitter search for #{search_term}"
        )
      end
      parsed_data
    end
  end
end