require 'lapis/error_codes'

module Parser
  class Base
    class << self
      def type
        raise NotImplementedError.new("Parser subclasses must implement type")
      end

      def patterns
        []
      end

      def ignored_urls
        []
      end

      def oembed_url(doc)
        return if doc.nil?
        tag = doc.at_css('link[type="application/json+oembed"]')
        tag.attribute('href').to_s unless tag.nil?
      end

      def match?(url)
        matched_pattern = false
        patterns.each do |pattern|
          matched_pattern = pattern.match?(url)
          return new(url) if matched_pattern
        end
        nil
      end
    end
    delegate :type, to: :class
    delegate :patterns, to: :class
    delegate :ignored_urls, to: :class

    def initialize(url)
      @url = url
      @unavailable_page = ignore_url?(url)
      @parsed_data = {}.with_indifferent_access
      @parsed_data[:raw] = {}
    end

    # This is the entry function for the class, which performs
    # any common setup and then calls down to `parse_data_for_parser`
    def parse_data(doc, original_url = nil, jsonld = [])
      # Shared setup
      set_raw_metatags(doc)

      # Parse data (implemented by subclasses)
      data = parse_data_for_parser(doc, original_url, jsonld || [])
      TracingService.add_attributes_to_current_span(
        'app.parser.type' => type,
        'app.parser.parsed_url' => url,
        'app.parser.original_url' => original_url
      )
      data
    end

    # Default implementation, subclasses can override
    def oembed_url(doc)
      self.class.oembed_url(doc)
    end

    attr_reader :url, :parsed_data

    private

    attr_reader :unavailable_page

    # Implemented by subclasses
    def parse_data_for_parser(doc, original_url, jsonld_array)
      raise NotImplementedError.new("Parser subclasses must implement parse_data_for_parser")
    end

    def ignore_url?(url)
      self.ignored_urls.each do |item|
        if url.match?(item[:pattern])
          return item[:reason]
        end
      end
      false
    end

    # Error-setting callback for RequestHelper.get_html
    def set_error(**error_hash)
      return if error_hash.empty?
      @parsed_data[:error] = error_hash
    end

    def set_data_field(field, *values)
      return parsed_data[field] unless parsed_data[field].blank?
      values.each do |value|
        next if value.blank?
        @parsed_data[field] = value
        break
      end
    end

    def get_metadata_from_tags(select_metatags)
      metadata = {}.with_indifferent_access
      select_metatags.each do |key, value|
        metatag_value = get_metadata_from_tag(value)
        metadata[key] = metatag_value unless metatag_value.blank?
      end
      metadata
    end

    def get_metadata_from_tag(value)
      metatag = (parsed_data['raw']['metatags'] || []).find { |tag| tag['property'] == value || tag['name'] == value }
      metatag['content'] if metatag
    end

    def set_raw_metatags(doc)
      metatag_data = []
      unless doc.nil?
        doc.search('meta').each do |meta|
          metatag = {}
          meta.each do |key, value|
            metatag.merge!({key.freeze => value.strip}) unless value.blank?
          end
          metatag_data << metatag
        end
      end
      @parsed_data['raw']['metatags'] = metatag_data
    end

    def refetch_html(url, html_options = {}, force_proxy = false)
      doc = RequestHelper.get_html(url, self.method(:set_error), html_options, force_proxy)
      set_raw_metatags(doc) if doc
      doc
    end

    def get_opengraph_metadata
      select_metatags = { title: 'og:title', picture: 'og:image', description: 'og:description', username: 'article:author', published_at: 'article:published_time', author_name: 'og:site_name' }
      data = get_metadata_from_tags(select_metatags).with_indifferent_access
      if (data['username'] =~ /\A#{URI::regexp}\z/)
        data['author_url'] = data['username']
        data.delete('username')
      end
      data['published_at'] = parse_published_time(data['published_at'])
      data
    end

    def get_twitter_metadata
      select_metatags = { title: 'twitter:title', picture: 'twitter:image', description: 'twitter:description', username: 'twitter:creator', author_name: 'twitter:site' }
      data = get_metadata_from_tags(select_metatags).with_indifferent_access

      data['author_url'] = twitter_author_url(data['username'])
      data.delete('author_name') if bad_username?(data['author_name'])
      unless data['author_url']
        data.delete('author_url')
        data.delete('username')
      end
      data
    end

    def twitter_author_url(username)
      return if bad_username?(username)
        "https://twitter.com/" + username[1..]
    end

    def bad_username?(value)
      value.blank? || value == '@username'
    end

    def parse_published_time(time)
      return if time.blank?
      begin
        Time.parse(time)
      rescue ArgumentError
        Time.at(time.to_i)
      end
    end

    def compare_patterns(compared_url, patterns, capture_group = 0)
      patterns.each do |p|
        match = compared_url.match p
        return match[capture_group] unless match.nil?
      end
      nil
    end

    def get_page_title(html_page)
      return if html_page.nil?

      meta_title = html_page.at_css('meta[property="og:title"]')
      html_title = html_page.at_css('title')

      meta_title&.attr('content') || html_title&.content
    end

    def handle_exceptions(exception)
      begin
        yield
      rescue exception => error
        PenderSentry.notify(error, url: url, parsed_data: parsed_data)
        code = Lapis::ErrorCodes::const_get('UNKNOWN')
        @parsed_data.merge!(error: { message: "#{error.class}: #{error.message}", code: code })
        Rails.logger.warn level: 'WARN', message: '[Parser] Could not parse', url: url, code: code, error_class: error.class, error_message: error.message
        return
      end
    end
  end
end
