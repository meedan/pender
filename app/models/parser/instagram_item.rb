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
    def parse_data_for_parser(doc, _original_url, _jsonld_array)
      id = url.match(INSTAGRAM_ITEM_URL)[3]
      @parsed_data.merge!(external_id: id)

      handle_exceptions(StandardError) do
        response_data = get_instagram_api_data("https://www.instagram.com/p/#{id}/?__a=1&__d=a")
        @parsed_data['raw']['api'] = response_data.dig('items', 0)

        username = get_instagram_username_from_data
        set_data_field('description', get_instagram_item_text_from_data)
        set_data_field('username', username)
        set_data_field('title', get_instagram_item_text_from_data)
        set_data_field('picture', get_instagram_item_picture_from_data)
        set_data_field('author_name', parsed_data.dig('raw', 'api', 'user', 'full_name'))
        set_data_field('author_url', username&.gsub(/^@/, 'https://instagram.com/'))
        set_data_field('author_picture', parsed_data.dig('raw', 'api', 'user', 'profile_pic_url'))
        set_data_field('published_at', Time.at(parsed_data.dig('raw', 'api', 'taken_at'))) unless parsed_data.dig('raw', 'api', 'taken_at').blank?
      end

      # Fallbacks from metatags, in case we cannot parse above
      username = get_instagram_username_from_twitter_title
      title = get_instagram_title_from_og_title
      set_data_field('title', title)
      set_data_field('description', title, url)
      set_data_field('picture', get_metadata_from_tag('og:image'))
      set_data_field('username', username)
      set_data_field('author_name', get_instagram_author_name_from_twitter_title)
      set_data_field('author_url', username&.gsub(/^@/, 'https://instagram.com/'))

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

    def get_instagram_title_from_og_title
      raw_title = get_metadata_from_tag('og:title')
      matches = raw_title&.match(/on Instagram:(|\s)"(?<title>.+)"/m)
      return if matches.blank?

      matches['title']
    end

    def get_instagram_username_from_twitter_title
      raw_username = get_metadata_from_tag('twitter:title')
      matches = raw_username&.match(/(?<author_name>.*) \(@(?<username>.+)\)/)
      return if matches.blank?

      matches['username'].prepend('@')
    end

    def get_instagram_author_name_from_twitter_title
      raw_username = get_metadata_from_tag('twitter:title')
      matches = raw_username&.match(/(?<author_name>.*) \(@(?<username>.+)\)/)
      return if matches.blank?

      matches['author_name']
    end
  end
end
