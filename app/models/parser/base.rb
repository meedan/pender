require 'error_codes'

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
      @parsed_data = {}.with_indifferent_access
      @parsed_data[:raw] = {}
    end
  
    def parse_data(doc)
      raise NotImplementedError.new("Parser subclasses must implement parse_data")
    end
  
    attr_reader :url, :parsed_data
    
    private

    def ignore_url?(url)
      self.ignored_urls.each do |item|
        if url.match?(item[:pattern])
          return item[:reason]
        end
      end
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
    
    def get_html_metadata(doc, metatags)
      raw_metatags = []
      metadata = {}.with_indifferent_access
      
      raw_metatags = get_raw_metatags(doc)
      metatags.each do |key, value|
        metatag = raw_metatags.find { |tag| tag['property'] == value || tag['name'] == value }
        metadata[key] = metatag['content'] if metatag
      end
      metadata['raw'] = { 'metatags' => raw_metatags }
      metadata
    end
  
    def get_raw_metatags(doc)
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
      metatag_data
    end
  
    def handle_exceptions(exception)
      begin
        yield
      rescue exception => error
        PenderAirbrake.notify(error, url: url, parsed_data: parsed_data )
        code = LapisConstants::ErrorCodes::const_get('UNKNOWN')
        @parsed_data.merge!(error: { message: "#{error.class}: #{error.message}", code: code })
        Rails.logger.warn level: 'WARN', message: '[Parser] Could not parse', url: url, code: code, error_class: error.class, error_message: error.message
        return
      end
    end
  end
end
