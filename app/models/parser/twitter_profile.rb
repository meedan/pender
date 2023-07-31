module Parser
  class TwitterProfile < Base
    include ProviderTwitter

    class << self
      def type
        'twitter_profile'.freeze
      end

      def patterns
        [
          /^https?:\/\/(www\.)?twitter\.com\/([^\/]+)$/,
          /^https?:\/\/(0|m|mobile)\.twitter\.com\/([^\/]+)$/
        ]
      end
    end

    private

    # Main function for class
    def parse_data_for_parser(doc, _original_url, _jsonld_array)
      @url = replace_subdomain_pattern(url)
      username = url.match(/^https?:\/\/(www\.)?twitter\.com\/([^\/]+)$/)[2]

      @parsed_data[:raw][:api] = {}
      handle_twitter_exceptions do
        @parsed_data[:raw][:api] = TwitterClient.user_lookup_by_username(username)
        picture_url = parsed_data[:raw][:api]['data'][0]['profile_image_url'].gsub('_normal', '')
        set_data_field('picture', picture_url)
        set_data_field('author_picture', picture_url)
      end
      @parsed_data[:error] = parsed_data.dig(:raw, :api, :error)
      username = parsed_data['raw']['api']['data'][0]['username']
      @parsed_data.merge!({
        url: url,
        external_id: username,
        username: '@' + username,
        author_name: parsed_data['raw']['api']['data'][0]['name'],
        description: parsed_data['raw']['api']['data'][0]['description'],
        published_at: parsed_data['raw']['api']['data'][0]['created_at'],
      })
      parsed_data
    end
  end
end
