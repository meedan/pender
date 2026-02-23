module Parser
  class TwitterItem < Base
    include ProviderTwitter

    TWITTER_ITEM_URL = /^https?:\/\/([^\.]+\.)?(twitter|x)\.com\/((%23|#)!\/)?(?<user>[^\/]+)\/status\/(?<id>[0-9]+).*/
    TWITTER_HOST = /^(https?:\/\/)?(www\.)?(x\.com|twitter\.com)(?:\/|$)/

    class << self
      def type
        'twitter_item'.freeze
      end
  
      def patterns
        [TWITTER_ITEM_URL, TWITTER_HOST]
      end
    end

    private

    # Main function for class
    def parse_data_for_parser(doc, _original_url, _jsonld_array)
      handle_exceptions(StandardError) do
        @url.gsub!(/(%23|#)!\//, '')
        @url.gsub!(/\s/, '')
        @url = replace_subdomain_pattern(url)
        parts = url.match(TWITTER_ITEM_URL)
        user, id = parts['user'], parts['id']
        doc = refetch_html(url) if doc.nil?
        @parsed_data.deep_merge!(OembedItem.new(url, oembed_url(doc)).get_data)
        @parsed_data.merge!(          
          external_id: id,
          username: '@' + user,
          author_url: get_author_url(user)
        )
        @parsed_data.merge!(format_oembed_data('item', parsed_data['raw']['oembed']))
      end
      parsed_data
    end

    def get_author_url(user)
      'https://twitter.com/' + user
    end
  end
end
