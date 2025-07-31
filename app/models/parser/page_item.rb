module Parser
  class PageItem < Base
    class HtmlFetchingError < StandardError; end

    class << self
      def type
        'page_item'.freeze
      end

      def patterns
        [/^.*$/]
      end
    end

    private

    # Main function for class
    def parse_data_for_parser(doc, original_url, _jsonld_array)
      doc = refetch_html(url) if doc.nil?

      handle_exceptions(StandardError) do
        raise HtmlFetchingError.new("Could not parse this media") if doc.blank?

        @parsed_data.deep_merge!(OembedItem.new(url, oembed_url(doc)).get_data)

        # The following will be merged in order, with later
        # values taking precedence and any empty values ignored.
        [
          get_metadata_from_tags({
            title: 'title', 
            description: 'description',
            username: 'author',
            author_name: 'application-name'
          }),
          get_html_info(doc),
          format_oembed_data(parsed_data['raw']['oembed']),
          get_opengraph_metadata,
          get_twitter_metadata,
        ].each do |hash|
          @parsed_data.merge!(hash.reject{|k,v| v.nil? })
        end

        unless parsed_data[:picture].blank?
          @parsed_data[:picture] = RequestHelper.add_scheme(parsed_data[:picture])
        end
        set_data_field('author_url', RequestHelper.top_url(url))
        set_data_field('author_name', parsed_data['author_name'], parsed_data['username'], parsed_data['title'])
        set_data_field('author_picture', parsed_data['picture'])

        cookie_metatag = get_metadata_from_tags({ cookie: 'pbContext' })
        @url = original_url if !cookie_metatag.empty? && !cookie_metatag[:cookie]&.match(/Cookie Absent/).nil?
      end

      urls_to_check = [url, parsed_data['author_url'], parsed_data['author_picture'], parsed_data['picture']].reject(&:blank?)
      raise Pender::Exception::UnsafeUrl if unsafe?(urls_to_check)

      parsed_data
    end

    def get_html_info(doc)
      {
        title: doc.at_css('title')&.content,
        description: doc.at_css('description')&.content,
      }
    end

    def format_oembed_data(oembed_data)
      # Adapted from Media.valid_raw_oembed?
      return {} unless oembed_data && oembed_data[:error].blank?
      {
        published_at: '',
        username: oembed_data.dig('author_name'),
        description: oembed_data.dig('summary') || oembed_data.dig('title'),
        title: oembed_data.dig('title'),
        picture: oembed_data.dig('thumbnail_url'),
        html: oembed_data.dig('html'),
        author_url: oembed_data.dig('author_url'),
      }
    end

    def unsafe?(urls)
      return if PenderConfig.get('google_api_key').blank?

      urls.each do |url|
        begin
          http = Net::HTTP.new('safebrowsing.googleapis.com', 443)
          http.use_ssl = true
          req = Net::HTTP::Post.new('/v4/threatMatches:find?key=' + PenderConfig.get('google_api_key'), 'Content-Type' => 'application/json')
          req.body = {
            client: {
              clientId: 'pender',
              clientVersion: VERSION
            },
            threatInfo: {
              threatTypes: ['MALWARE', 'SOCIAL_ENGINEERING', 'THREAT_TYPE_UNSPECIFIED', 'UNWANTED_SOFTWARE', 'POTENTIALLY_HARMFUL_APPLICATION'],
              platformTypes: ['ANY_PLATFORM'],
              threatEntryTypes: ['URL'],
              threatEntries: [{ url: url }]
            }
          }.to_json
          res = http.request(req)
          return true if JSON.parse(res.body)['matches'].size > 0
        rescue
          next
        end
      end
      false
    end
  end
end
