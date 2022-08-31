module ProviderYoutube
  extend ActiveSupport::Concern

  class_methods do
    def ignored_urls
      [{ pattern: /^https:\/\/consent.youtube.com/, reason: :consent_page }]
    end
  end

  # def oembed_url
  #   "https://www.youtube.com/oembed?format=json&url=#{url}"
  # end

  def initialize(doc)
    super(doc)

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

  def get_opengraph_metadata(raw_metatags)
    select_metatags = { title: 'og:title', picture: 'og:image', description: 'og:description', username: 'article:author', published_at: 'article:published_time', author_name: 'og:site_name' }
    data = get_metadata_from_tags(raw_metatags, select_metatags).with_indifferent_access
    if (data['username'] =~ /\A#{URI::regexp}\z/)
      data['author_url'] = data['username']
      data.delete('username')
    end
    data['published_at'] = parse_published_time(data['published_at'])
    data
  end
end
