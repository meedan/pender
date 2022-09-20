module Parser
  class InstagramItem < Base
    include ProviderInstagram

    INSTAGRAM_ITEM_URL = /^https?:\/\/(www\.)?instagram\.com\/(p|tv|reel)\/([^\/]+)/
    
    class << self
      def type
        'instagram_item'.freeze
      end

      def patterns
        [INSTAGRAM_ITEM_URL]
      end
    end
    
    private

    # Main function for class
    def parse_data_for_parser(doc, _original_url, _jsonld)
      id = url.match(INSTAGRAM_ITEM_URL)[3]

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
  end
end
