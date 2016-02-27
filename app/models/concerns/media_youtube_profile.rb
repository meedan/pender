module MediaYoutubeProfile
  extend ActiveSupport::Concern

  included do
    Media.declare('youtube_profile', [/^https?:\/\/(www\.)?youtube\.com\/user\/([^\/]+)$/])
  end

  def data_from_youtube_profile
    channel = Yt::Channel.new url: self.url
    data = {}
    %w(title description published_at thumbnail_url view_count subscriber_count).each do |attr|
      data[attr] = channel.send(attr)
    end
    self.data = data
  end
end
