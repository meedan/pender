module Parser
  class InstagramProfile < Base
    include ProviderInstagram
    
    INSTAGRAM_PROFILE_URL = /^https?:\/\/(www\.)?instagram\.com\/([^\/]+)/

    class << self
      def type
        'instagram_profile'.freeze
      end

      def patterns
        [INSTAGRAM_PROFILE_URL]
      end
    end

    private
    
    # Main function for class
    def parse_data_for_parser(doc, _ = nil)
      username = url.match(INSTAGRAM_PROFILE_URL)[2]
      @parsed_data.merge!({
        'external_id': username,
        'username': '@' + username,
        'title': username,
        'description': url,      
      })

      handle_exceptions(StandardError) do
        response_data = get_instagram_api_data(
          "https://i.instagram.com/api/v1/users/web_profile_info/?username=#{username}",
          additional_headers: { 'x-ig-app-id': '936619743392459' }
        )
        @parsed_data['raw']['api'] = response_data['data']
        
        # If we use set_data_field, it won't override the default value above
        @parsed_data['description'] = parsed_data.dig('raw', 'api', 'user', 'biography')
        set_data_field('picture', parsed_data.dig('raw', 'api', 'user', 'profile_pic_url'))
        set_data_field('author_name', parsed_data.dig('raw', 'api', 'user', 'full_name'))
        set_data_field('author_picture', parsed_data.dig('raw', 'api', 'user', 'profile_pic_url'))
        set_data_field('published_at', '')
      end
      parsed_data
    end
  end
end 
