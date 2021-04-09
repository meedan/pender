module MediaYoutubeItem
  extend ActiveSupport::Concern

  included do
    Media.declare('youtube_item', [/^https?:\/\/(www\.)?youtube\.com\/watch\?v=([^&]+)/])
  end

  def youtube_item_direct_attributes
    %w(
      description
      title
      published_at
      thumbnails
      channel_title
      channel_id
      id
    )
  end

  def data_from_youtube_item
    video = video_data = nil

    self.data[:raw] ||= {}
    self.data[:raw][:api] = {}

    begin
      Yt.configuration.api_key = PenderConfig.get(:google_api_key)
      video = Yt::Video.new url: self.url
      video_data = video.snippet.data
      self.youtube_item_direct_attributes.each do |attr|
        self.data[:raw][:api][attr] = video_data.dig(attr.camelize(:lower)) || video.send(attr) || ''
      end
    rescue Yt::Errors::NoItems => e
      self.data['username'] = self.data['author_name'] = 'YouTube'
      self.data['title'] = 'Deleted video'
      self.data['description'] = 'This video is unavailable.'
      self.data[:raw][:api] = { error: { message: e.message, code: LapisConstants::ErrorCodes::const_get('NOT_FOUND') }}
    rescue Yt::Errors::Forbidden => e
      self.data[:raw][:api] = { error: { message: e.message, code: LapisConstants::ErrorCodes::const_get('UNAUTHORIZED') }}
    end

    id = get_info_from_data('api', data, 'id')

    metadata = self.get_opengraph_metadata || {}
    self.set_data_field('title', get_info_from_data('api', data, 'title'), metadata.dig('title'))
    self.set_data_field('description', get_info_from_data('api', data, 'description'), metadata.dig('description'))
    self.set_data_field('picture', self.get_youtube_thumbnail, metadata.dig('picture'))
    self.set_data_field('username', get_info_from_data('api', data, 'channel_title'))
    self.data.merge!({
      external_id: id,
      html: html_for_youtube_item(id),
      author_name: get_info_from_data('api', data, 'channel_title'),
      author_picture: self.get_youtube_item_author_picture, 
      author_url: self.get_youtube_item_author_url,
      published_at: get_info_from_data('api', data, 'published_at')
    })
  end

  def get_youtube_item_author_url
    cid = data[:raw][:api]['channel_id']
    cid.blank? ? '' : "https://www.youtube.com/channel/#{cid}"
  end

  def get_youtube_thumbnail
    thumbnails = self.get_info_from_data('api', data, 'thumbnails')
    return '' unless thumbnails.is_a?(Hash)
    ['maxres', 'standard', 'high', 'medium', 'default'].each do |size|
      return thumbnails.dig(size, 'url') unless thumbnails.dig(size).nil?
    end
  end

  def get_youtube_item_author_picture
    begin
      channel = Yt::Channel.new id: self.data[:raw][:api]['channel_id']
      channel.thumbnail_url.to_s
    rescue
      ''
    end
  end

  def youtube_oembed_url
    "https://www.youtube.com/oembed?format=json&url=#{self.url}"
  end

  def html_for_youtube_item(id)
    return '' if data[:raw][:api]['channel_id'].blank?
    "<iframe width='480' height='270' src='//www.youtube.com/embed/#{id}' frameborder='0' allow='accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture' allowfullscreen></iframe>"
  end
end
