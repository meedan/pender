module Parser
  class InstagramProfile < Base
    include ProviderInstagram

    INSTAGRAM_PROFILE_URL = /^https?:\/\/(www\.)?instagram\.com\/([^\/\?]+)/

    class << self
      def type
        'instagram_profile'.freeze
      end

      def patterns
        [INSTAGRAM_PROFILE_URL]
      end

      def urls_parameters_to_remove
        ['igsh']
      end
    end

    private

    # Main function for class
    def parse_data_for_parser(doc, _original_url, _jsonld_array)
      username = url.match(INSTAGRAM_PROFILE_URL)[2]
      @parsed_data.merge!(
        'external_id' => username,
        'username' => "@#{username}",
        'title' => username,
        'description' => url
      )

      handle_exceptions(StandardError) do
        apify_data = get_instagram_profile_data_from_apify(username)
        return unless apify_data

        @parsed_data['raw']['apify'] = apify_data

        # Update fields with Apify data
        @parsed_data['description'] = parsed_data.dig('raw', 'apify', 'biography')
        set_data_field('picture', parsed_data.dig('raw', 'apify', 'profile_pic_url'))
        set_data_field('author_name', parsed_data.dig('raw', 'apify', 'full_name'))
        set_data_field('author_picture', parsed_data.dig('raw', 'apify', 'profile_pic_url'))
        set_data_field('published_at', '')
      end
      parsed_data
    end

    def get_instagram_profile_data_from_apify(username)
      profile_url = "https://www.instagram.com/#{username}/"
      Media.apify_request(profile_url, :instagram)
    end
  end
end
