module Parser
  class TwitterProfile < Base
    include ProviderTwitter

    class << self
      def type
        'twitter_profile'.freeze
      end

      def patterns
        [
          /^https?:\/\/((0|m|mobile|www)\.)?(twitter|x)\.com\/(?<username>[\w]{4,15})[\/]*(\?.*)?[\/]*$/
        ]
      end
    end

    private

    # Main function for class
    def parse_data_for_parser(doc, _original_url, _jsonld_array)
      handle_exceptions(StandardError) do
        @url.gsub!(/\s/, '')
        @url = replace_subdomain_pattern(url)
        username = compare_patterns(@url, self.patterns, 'username')
        @parsed_data.deep_merge!(twitter_oembed_data(doc, url))
        @parsed_data.merge!(
          url: url,
          external_id: username,
          username: '@' + username,
          title: username,
        )
        @parsed_data.merge!(format_oembed_data('profile', parsed_data['raw']['oembed']))
      end
      parsed_data
    end
  end
end
