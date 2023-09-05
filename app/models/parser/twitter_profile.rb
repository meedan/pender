module Parser
  class TwitterProfile < Base
    include ProviderTwitter

    class << self
      def type
        'twitter_profile'.freeze
      end

      def patterns
        [
          /^https?:\/\/(www\.)?twitter\.com\/(?<username>[\w\d]+)\?*[^\/]+$/,
          /^https?:\/\/(0|m|mobile)\.twitter\.com\/(?<username>[\w\d]+)\?*[^\/]+$/
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
        
        @parsed_data.merge!(
          url: url,
          external_id: username,
          username: '@' + username,
          title: username,
        )
        
        @parsed_data[:raw][:api] = user_lookup_by_username(username)
        @parsed_data[:error] = parsed_data.dig('raw', 'api', 'errors')
        
        if @parsed_data[:error] 
          @parsed_data.merge!(author_name: username)
        elsif @parsed_data[:error].nil?
          raw_data = parsed_data.dig('raw', 'api', 'data', 0)

          @parsed_data.merge!({
            picture: raw_data['profile_image_url'].gsub('_normal', ''),
            author_name: raw_data['name'],
            author_picture: raw_data['profile_image_url'].gsub('_normal', ''),
            description: raw_data['description'].squish,
            published_at: raw_data['created_at']
          })
        end
      end 
      parsed_data
    end
  end
end
