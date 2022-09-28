module ProviderYoutube
  extend ActiveSupport::Concern

  class_methods do
    def ignored_urls
      [{ pattern: /^https:\/\/consent.youtube.com/, reason: :consent_page }]
    end
  end

  def oembed_url(_ = nil)
    "https://www.youtube.com/oembed?format=json&url=#{self.url}"
  end

  def initialize(url)
    super(url)

    Yt.configuration.api_key = PenderConfig.get(:google_api_key)
  end

  private

  def get_thumbnail(data)
    thumbnails = data.dig('raw','api','thumbnails')
    return '' unless thumbnails.is_a?(Hash)
    ['maxres', 'standard', 'high', 'medium', 'default'].each do |size|
      return thumbnails.dig(size, 'url') unless thumbnails.dig(size).nil?
    end
  end

  def handle_youtube_exceptions
    begin
      yield
    rescue Yt::Errors::NoItems => error
      set_deleted_info(error)
      Rails.logger.warn level: 'WARN', message: "[Parser] #{error.message}", url: url, error_class: error.class
    rescue Yt::Errors::Forbidden => error
      PenderAirbrake.notify(error, url: url )
      @parsed_data[:raw][:api] = { error: { url: url, message: "#{error.class}: #{error.message}", code: LapisConstants::ErrorCodes::const_get('UNAUTHORIZED') }}
      Rails.logger.warn level: 'WARN', message: "[Parser] #{error.message}", url: url, error_class: error.class
    end
  end

  def set_deleted_info(error)
    @parsed_data['username'] = @parsed_data['author_name'] = 'YouTube'
    @parsed_data['title'] = 'Deleted video'
    @parsed_data['description'] = 'This video is unavailable.'
    @parsed_data[:raw][:api] = { error: { message: error.message, code: LapisConstants::ErrorCodes::const_get('NOT_FOUND') }}
  end
end
