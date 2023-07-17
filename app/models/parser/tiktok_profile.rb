module Parser
  class TiktokProfile < Base
    include ProviderTiktok

    TIKTOK_PROFILE_URL = /^https?:\/\/(www\.)?tiktok\.com\/(?<username>@[^\/\?]+)/

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
    def parse_data_for_parser(doc, _original_url, jsonld_array)
      match = url.match(TIKTOK_PROFILE_URL)
      base_url = match[0] # Should this be set as canonical_url?
      username = match['username']
      jsonld = (jsonld_array.find{|item| item.dig('@type') == 'Person'} || {})

      @parsed_data.merge!(url: base_url)

      handle_exceptions(StandardError) do
        doc = reparse_if_default_tiktok_page(doc, base_url) || doc
        set_data_field('title', jsonld.dig('name'), get_metadata_from_tag('twitter:creator'))
        set_data_field('picture', get_metadata_from_tag('og:image'))
        set_data_field('description', jsonld.dig('description'))
        set_data_field('author_name', jsonld.dig('name'))
        set_data_field('author_picture', parsed_data['picture'])
      end

      # Set defaults if above fails
      set_data_field('external_id', username)
      set_data_field('username', username)
      set_data_field('title', username)
      set_data_field('author_name', username)
      set_data_field('description', base_url)
      set_data_field('author_url', base_url)

      parsed_data
    end

    def reparse_if_default_tiktok_page(doc, base_url)
      if doc&.css('title')&.text == 'TikTok'
        refetch_html(base_url, RequestHelper.html_options(base_url), true)
      end
    end
  end
end
