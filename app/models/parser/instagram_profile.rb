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
        'title' => username
      )

      handle_exceptions(StandardError) do
        apify_data = get_instagram_profile_data_from_apify(username)
        return unless apify_data

        @parsed_data['raw']['apify'] = apify_data[0]

        # Update fields with Apify data
        set_data_field('picture', parsed_data.dig('raw', 'apify', 'profilePicUrl'))
        set_data_field('author_url', url)
        set_data_field('username', parsed_data.dig('raw', 'apify', 'fullName'))
        set_data_field('description', parsed_data.dig('raw', 'apify', 'biography'))
        set_data_field('author_name', parsed_data.dig('raw', 'apify', 'fullName'))
        set_data_field('author_picture', parsed_data.dig('raw', 'apify', 'profilePicUrl'))
        set_data_field('picture', @parsed_data['raw']['apify']['profilePicUrl'])
        set_data_field('published_at', '')
      end

      @parsed_data['description'] ||= url
      @parsed_data['html'] = html_for_instagram_profile(doc, url) || ''
      parsed_data
    end

    def get_instagram_profile_data_from_apify(username)
      profile_url = "https://www.instagram.com/#{username}/"
      Media.apify_request(profile_url, :instagram)
    end

    def html_for_instagram_profile(html_page, request_url)
      return unless html_page

      request_url = request_url + "/" unless request_url.end_with? "/"

      '<div><iframe src="' + request_url + 'embed" width="397" height="477" frameborder="0" scrolling="no" allowtransparency="true"></iframe></div>'
    end
  end
end
