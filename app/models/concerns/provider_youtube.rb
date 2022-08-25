module ProviderYoutube
  extend ActiveSupport::Concern

  class_methods do
    def ignored_urls
      [{ pattern: /^https:\/\/consent.youtube.com/, reason: :consent_page }]
    end
  end

  private

  def get_youtube_thumbnail(data)
    thumbnails = data.dig('raw','api','thumbnails')
    return '' unless thumbnails.is_a?(Hash)
    ['maxres', 'standard', 'high', 'medium', 'default'].each do |size|
      return thumbnails.dig(size, 'url') unless thumbnails.dig(size).nil?
    end
  end

  def handle_youtube_exceptions
    begin
      yield
    # rescue Yt::Errors::NoItems => e
    #   self.set_youtube_item_deleted_info(e)
    rescue Yt::Errors::Forbidden => error
      PenderAirbrake.notify(error, url: url )
      @parsed_data[:raw][:api] = { error: { url: url, message: "#{error.class}: #{error.message}", code: LapisConstants::ErrorCodes::const_get('UNAUTHORIZED') }}
      Rails.logger.warn level: 'WARN', message: "[Parser] #{error.message}", url: url, error_class: error.class
    end
  end
end
