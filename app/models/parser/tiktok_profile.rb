module Parser
  class TiktokProfile < Base
    include ProviderTiktok

    TIKTOK_PROFILE_URL = /^https?:\/\/(www\.)?tiktok\.com\/(?<username>[^\/\?]+)/

    class << self
      def type
        'tiktok_profile'.freeze
      end
      
      def patterns
        [TIKTOK_PROFILE_URL]
      end
    end

    private
    
    # Main function for class
    def parse_data_for_parser(doc, _ = nil)
      match = url.match(TIKTOK_PROFILE_URL)
      base_url = match[0] # Should this be set as canonical_url?
      username = match['username']

      set_data_field('external_id', username)
      set_data_field('username', username)
      set_data_field('title', username)
      set_data_field('author_name', username)
      set_data_field('description', base_url)

      handle_exceptions(StandardError) do
        doc = reparse_if_default_tiktok_page(doc, base_url) || doc
        select_metatags = { picture: 'og:image', title: 'twitter:creator', description: 'description' }
        @parsed_data.merge!(get_metadata_from_tags(select_metatags))
        set_data_field('author_name', parsed_data['title'], username)
        @parsed_data.merge!({
          author_name: parsed_data['title'],
          author_picture: parsed_data['picture'],
          author_url: base_url,
          url: base_url
        })
      end
      parsed_data
    end

    def reparse_if_default_tiktok_page(doc, base_url)
      if doc.css('title').text == 'TikTok'
        RequestHelper.get_html(base_url, self.method(:set_error), RequestHelper.html_options(base_url), true)
      end
    end
  end
end
