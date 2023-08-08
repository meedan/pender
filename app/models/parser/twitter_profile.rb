module Parser
  class TwitterProfile < Base
    include ProviderTwitter

    class << self
      def type
        'twitter_profile'.freeze
      end

      def patterns
        [
          /^https?:\/\/(www\.)?twitter\.com\/(?<username>[^\/]+)$/,
          /^https?:\/\/(0|m|mobile)\.twitter\.com\/(?<username>[^\/]+)$/
        ]
      end
    end

    private

    # Main function for class
    def parse_data_for_parser(doc, _original_url, _jsonld_array)
      @url.gsub!(/\s/, '')
      @url = replace_subdomain_pattern(url)      
      username = compare_patterns(@url, self.patterns, 'username')

      @parsed_data[:raw][:api] = {}      
      @parsed_data[:raw][:api] = user_lookup_by_username(username)
      
      @parsed_data[:error] = parsed_data['raw']['api']['errors']
      
      if @parsed_data[:error] 
        picture = ''
        author_name = username
        description = ''
        published_at = ''
      elsif @parsed_data[:error].nil?
        picture = parsed_data[:raw][:api]['data'][0]['profile_image_url'].gsub('_normal', '')
        author_name = parsed_data['raw']['api']['data'][0]['name']
        description = parsed_data['raw']['api']['data'][0]['description'].squish
        published_at = parsed_data['raw']['api']['data'][0]['created_at']
      end
 
      @parsed_data.merge!({
        url: url,
        external_id: username,
        username: '@' + username,
        title: username,
        description: description,
        picture: picture,
        author_picture: picture,
        published_at: published_at,
        author_name: author_name,
      })
      parsed_data
    end
  end
end
