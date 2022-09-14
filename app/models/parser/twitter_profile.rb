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
    def parse_data_for_parser(doc, _ = nil)
      @url = replace_subdomain_pattern(url)
      username = url.match(/^https?:\/\/(www\.)?twitter\.com\/([^\/]+)$/)[2]

      @parsed_data[:raw][:api] = {}
      handle_twitter_exceptions do
        @parsed_data[:raw][:api] = twitter_client.user(username).as_json
        picture_url = parsed_data[:raw][:api][:profile_image_url_https].gsub('_normal', '')
        set_data_field('picture', picture_url)
        set_data_field('author_picture', picture_url)
      end
      @parsed_data[:error] = parsed_data.dig(:raw, :api, :error)
      set_data_field('title', parsed_data.dig(:raw, :api, :name), username)
      @parsed_data.merge!({
        url: url,
        external_id: username,
        username: '@' + username,
        author_name: parsed_data[:title],
        description: parsed_data.dig(:raw, :api, :description),
        published_at: parsed_data.dig(:raw, :api, :created_at),
      })
      parsed_data
    end
  end
end
