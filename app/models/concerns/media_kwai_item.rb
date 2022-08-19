class MediaKwaiItem
  KWAI_URL = /^https?:\/\/([^.]+\.)?(kwai\.com|kw\.ai)\//

  class << self
    def type
      'kwai_item'.freeze
    end

    def patterns
      [KWAI_URL]
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

  def initialize(url)
    @url = url
    @parsed_data = {}
  end

  def parse_data(doc)
    return parsed_data unless parsed_data.blank?
    handle_exceptions(StandardError) do
      title = get_kwai_text_from_tag(doc, '.info .title')
      name = get_kwai_text_from_tag(doc, '.name')
      @parsed_data.merge!({
        title: title,
        description: title,
        author_name: name,
        username: name
      })
    end
    parsed_data
  end

  attr_reader :url, :parsed_data

  private

  def get_kwai_text_from_tag(doc, selector)
    doc&.at_css(selector)&.text&.to_s.strip
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
