module Parser
  class FacebookProfile < Base
    include ProviderFacebook

    class << self
      def type
        'facebook_profile'.freeze
      end

      # As of 8/30/22, Facebook will redirect any numeric page URL to the human-readable equivalent
      # (eg http://facebook.com/513415662050479 to http://facebook.com/helloween) even without login.
      # 
      # Since we follow redirects before trying to match pattern and instantiating this class,
      # we never really hit a case where the URL matches the pattern described above. Despite that,
      # we've left the cases in patterns below and in unit tests, in case their or our behavior changes -
      # and because they're valid Facebook profile URLs.
      def patterns
        [
          /^https?:\/\/([^\.]+\.)?facebook\.com\/(pages|people)\/(?<username>[^\/]+)\/(?<id>[^\/\?]+)((?!\/photos\/?).)*$/,
          /^https?:\/\/(www\.)?facebook\.com\/profile\.php\?id=(?<username>[0-9]+).*$/,
          /^https?:\/\/([^\.]+\.)?facebook\.com\/(?!(permalink\.php|story\.php|photo(\.php)?|livemap|watch))(?<username>[^\/\?]+)\/?(\?.*)*$/
        ]
      end
    end
    
    private

    # Main function for class
    def parse_data_for_parser(doc, original_url, _jsonld_array)
      parseable_url = unavailable_page ? original_url : url

      handle_exceptions(StandardError) do
        @parsed_data['external_id'] = get_id_from_url(parseable_url, original_url) || self.class.get_id_from_doc(doc) || ''
        @parsed_data['id'] = parsed_data['external_id']
        
        picture = get_metatag_value('og:image')
        set_data_field('author_picture', picture)
        set_data_field('picture', picture)

        username = get_username(parseable_url)
        set_data_field('username', username)
        
        title = get_unique_facebook_page_title(doc)
        set_data_field('title', title)
        set_data_field('author_name', username, title, 'Facebook')

        set_data_field('description', get_metatag_value('og:description'), get_metatag_value('description'))
        set_data_field('author_url', parseable_url)
        set_facebook_dead_end_error(doc, unavailable_page)
      end

      strip_facebook_from_title!

      @parsed_data['published_at'] = ''
      parsed_data
    end

    def get_metatag_value(name)
      value = nil
      (parsed_data.dig('raw', 'metatags') || []).each do |tag|
        value = tag['content'] if (tag['name'] == name || tag['property'] == name)
      end
      value
    end

    def get_username(request_url)
      username = compare_patterns(RequestHelper.decode_uri(request_url), self.patterns, 'username')
      return if NONUNIQUE_TITLES.include? username
      return if username.to_i > 0

      username
    end

    def get_id_from_url(request_url, original_url)
      # Same as self.patterns, but only targeting numeric IDs (not usernames)
      id_patterns = [
        /^https?:\/\/([^\.]+\.)?facebook\.com\/(pages|people)\/([^\/]+)\/(?<id>[0-9]+)((?!\/photos\/?).)*$/,
        /^https:\/\/(www\.)?facebook\.com\/profile\.php\?id=(?<id>[0-9]+)*$/,
        /^https?:\/\/([^\.]+\.)?facebook\.com\/(?!(permalink\.php|story\.php|photo(\.php)?|livemap|watch))(?<id>[0-9]+)\/?(\?.*)*$/,
      ]
      id = nil
      [request_url, original_url].each do |compared_url|
        if matched_id = compare_patterns(compared_url, id_patterns, 'id')
          id = matched_id
          break
        end
      end
      id
    end
  end
end
