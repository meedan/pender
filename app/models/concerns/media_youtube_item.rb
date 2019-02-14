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
      embed_html
      channel_title
      channel_id
    )
  end

  def data_from_youtube_item
    video = Yt::Video.new url: self.url
    video_data = video.snippet.data

    self.data[:raw][:api] = {}
    self.youtube_item_direct_attributes.each do |attr|
      self.data[:raw][:api][attr] = video_data.dig(attr.camelize(:lower)) || video.send(attr)
    end

    data = self.data

    self.data.merge!({
      username: data[:raw][:api]['channel_title'],
      description: data[:raw][:api]['description'],
      title: data[:raw][:api]['title'],
      picture: self.get_youtube_thumbnail,
      html: data[:raw][:api]['embed_html'],
      author_name: data[:raw][:api]['channel_title'],
      author_picture: self.get_youtube_item_author_picture, 
      author_url: 'https://www.youtube.com/channel/' + data[:raw][:api]['channel_id'],
      published_at: data[:raw][:api]['published_at']
    })
  end

  def get_youtube_thumbnail
    thumbnails = self.get_info_from_data('api', data, 'thumbnails')
    ['maxres', 'standard', 'high', 'medium', 'default'].each do |size|
      return thumbnails.dig(size, 'url') unless thumbnails.dig(size).nil?
    end
  end

  def get_youtube_item_author_picture
    channel = Yt::Channel.new id: self.data[:raw][:api]['channel_id']
    channel.thumbnail_url.to_s
  end

  def youtube_oembed_url
    "https://www.youtube.com/oembed?format=json&url=#{self.url}"
  end

end
