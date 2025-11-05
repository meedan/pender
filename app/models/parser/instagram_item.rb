module Parser
  class InstagramItem < Base
    include ProviderInstagram

    INSTAGRAM_ITEM_URL = /^https?:\/\/(www\.)?instagram\.com\/(p|tv|reel)\/([^\/]+)/
    INSTAGRAM_HOME_URL = /^(https?:\/\/)?(www\.)?instagram\.com\/?$/

    class << self
      def type
        'instagram_item'.freeze
      end

      def patterns
        [INSTAGRAM_ITEM_URL, INSTAGRAM_HOME_URL]
      end

      def urls_parameters_to_remove
        ['igsh']
      end
    end

    private

    def parse_data_for_parser(doc, original_url, _jsonld_array)
      id = url.match(INSTAGRAM_ITEM_URL)[3]
      @parsed_data.merge!(external_id: id)

      handle_exceptions(StandardError) do
        apify_data = get_instagram_data_from_apify(id)
        
        if apify_data
          @parsed_data['raw']['apify'] = apify_data[0]
          description = description(@parsed_data['raw']['apify'])

          set_data_field('title', description)
          set_data_field('description', description)
          set_data_field('username', "@#{@parsed_data['raw']['apify']['ownerUsername']}")
          set_data_field('picture', image(@parsed_data['raw']['apify']))
          set_data_field('author_name', author_name(@parsed_data['raw']['apify']))
          set_data_field('author_url', "https://instagram.com/#{@parsed_data['raw']['apify']['ownerUsername']}")
          set_data_field('author_picture', @parsed_data['raw']['apify'].dig('latestComments', 0, 'ownerProfilePicUrl'))
          set_data_field('published_at', @parsed_data['raw']['apify']['timestamp'] ? Time.parse(@parsed_data['raw']['apify']['timestamp']) : nil)
        else
          @parsed_data['error'] = { 'message' => 'Apify data not found or link is inaccessible' }
          set_data_field('title', get_metadata_from_tag(doc, 'og:title') || get_metadata_from_tag(doc, 'twitter:title'))
          set_data_field('description', @parsed_data['title'])
          set_data_field('username', get_metadata_from_tag(doc, 'twitter:title')&.match(/\((@[^)]+)\)/)&.captures&.first)
          set_data_field('picture', get_metadata_from_tag(doc, 'og:image'))
          set_data_field('author_name', @parsed_data['title']&.split&.first)
          set_data_field('author_url', "https://instagram.com/#{@parsed_data['username']}")
        end
      end

      @parsed_data['description'] ||= url
      @parsed_data['html'] = html_for_instagram_post(parsed_data.dig('username'), doc, url) || ''
      parsed_data
    end

    # Helper method to retrieve meta tag content
    def get_metadata_from_tag(doc, tag_name)
      return if doc.nil?
      tag = doc.at("meta[property='#{tag_name}']") || doc.at("meta[name='#{tag_name}']")
      tag['content'] if tag
    end

    def get_instagram_data_from_apify(id)
      Media.apify_request("https://www.instagram.com/p/#{id}/", :instagram)
    end

    def html_for_instagram_post(username, html_page, request_url)
      return unless html_page

      request_url = request_url.sub(/\?.*/, '')
      request_url = request_url + "/" unless request_url.end_with? "/"

      '<div><iframe src="' + request_url + 'embed" width="397" height="477" frameborder="0" scrolling="no" allowtransparency="true"></iframe></div>'
    end

    def description(apify_data)
      apify_data['caption'] || apify_data['description']
    end

    def image(apify_data)
      apify_data['displayUrl'] || apify_data['image']
    end

    def author_name(apify_data)
      name = apify_data['ownerFullName'] || apify_data['title']
      name.split('•').first.strip if name.present?
    end
  end
end
