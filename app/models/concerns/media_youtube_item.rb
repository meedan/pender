module MediaYoutubeItem
  extend ActiveSupport::Concern

  included do
    # https://www.youtube.com/watch?v=601yfqd3DwM&feature=youtu.be
    Media.declare('youtube_item', [/^https?:\/\/(www\.)?youtube\.com\/watch\?v=([^&]+)/])
  end

  def youtube_item_direct_attributes
    %w(
      description
      title
      published_at
      thumbnail_url
      embed_html
      channel_title
      channel_id
    )
  end

  def data_from_youtube_item
    video = Yt::Video.new url: self.url

    self.youtube_item_direct_attributes.each do |attr|
      self.data[attr] = video.send(attr)
    end

    data = self.data

    self.data.merge!({
      username: data['channel_title'],
      picture: data['thumbnail_url'],
      html: data['embed_html'],
      author_picture: self.get_youtube_item_author_picture, 
      author_url: 'https://www.youtube.com/channel/' + data['channel_id']
    })
  end

  def get_youtube_item_author_picture
    channel = Yt::Channel.new id: self.data['channel_id']
    channel.thumbnail_url.to_s
  end
end
