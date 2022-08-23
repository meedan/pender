require 'instagram_exceptions'

module Parser
  class InstagramItem < Base
    INSTAGRAM_ITEM_URL = /^https?:\/\/(www\.)?instagram\.com\/(p|tv|reel)\/([^\/]+)/
    class << self
      def type
        'instagram_item'.freeze
      end

      def patterns
        [INSTAGRAM_ITEM_URL]
      end

      def ignored_urls
        [
          {
            pattern: /^https:\/\/www\.instagram\.com\/accounts\/login/,
            reason: :login_page
          },
          {
            pattern: /^https:\/\/www\.instagram\.com\/challenge\?/,
            reason: :account_challenge_page
          },
          {
            pattern: /^https:\/\/www\.instagram\.com\/privacy\/checks/, 
            eason: :privacy_check_page
          },
        ]
      end
    end

    def parse_data(doc)
      id = self.url.match(INSTAGRAM_ITEM_URL)[3]

      @parsed_data.merge!(external_id: id)
      set_data_field('description', url)

      handle_exceptions(StandardError) do
        response_data = get_instagram_api_data("https://www.instagram.com/p/#{id}/?__a=1&__d=a")
        @parsed_data['raw'] = { 'api' => response_data.dig('items', 0) }

        username = get_instagram_username_from_data
        # If we use set_data_field, it won't override the default value above
        @parsed_data['description'] = get_instagram_item_text_from_data
        set_data_field('username', username)
        set_data_field('title', get_instagram_item_text_from_data)
        set_data_field('picture', get_instagram_item_picture_from_data)
        set_data_field('author_name', parsed_data.dig('raw', 'api', 'user', 'full_name'))
        set_data_field('author_url', username.gsub(/^@/, 'https://instagram.com/'))
        set_data_field('author_picture', parsed_data.dig('raw', 'api', 'user', 'profile_pic_url'))
        set_data_field('published_at', Time.at(parsed_data.dig('raw', 'api', 'taken_at')))
      end
      parsed_data
    end

    private

    def get_instagram_username_from_data
      username = parsed_data.dig('raw', 'api', 'user', 'username').to_s
      username.prepend('@') unless username.blank?
    end

    def get_instagram_item_text_from_data
      parsed_data.dig('raw', 'api', 'caption', 'text').to_s
    end

    def get_instagram_item_picture_from_data
      parsed_data.dig('raw', 'api', 'image_versions2', 'candidates', 0, 'url') ||
        parsed_data.dig('raw', 'api', 'carousel_media', 0, 'image_versions2', 'candidates', 0, 'url')
    end

    def get_instagram_api_data(api_url, additional_headers: {})
      begin
        uri = URI.parse(api_url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        
        headers = Media.extended_headers(uri)
        headers.merge!(additional_headers)

        request = Net::HTTP::Get.new(uri.request_uri, headers)
        response = http.request(request)
        raise Instagram::ApiResponseCodeError.new("#{response.class}: #{response.message}") unless %(200 301 302).include?(response.code)
        return JSON.parse(response.body) if response.code == '200'

        location = response.header['location']
        if unavailable_reason = ignore_url?(location)
          raise Instagram::ApiAuthenticationError.new("Page unreachable, received redirect for #{unavailable_reason} to #{location}")
        else
          get_instagram_api_data(location)
        end
      # Deliberately catch and re-wrap any errors we think are related
      # to the API not working as expected, so that we can monitor them
      rescue JSON::ParserError, Instagram::ApiResponseCodeError, Instagram::ApiAuthenticationError => e
        raise Instagram::ApiError.new("#{e.class}: #{e.message}")
      end
    end
  end
end
