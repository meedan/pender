class BaseParser

  class << self
    def type
      raise NotImplementedError
    end

    def patterns
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

  def initialize(url)
    @url = url
    @parsed_data = {}
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
