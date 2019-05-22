module MediaYoutubeProfile
  extend ActiveSupport::Concern

  included do
    Media.declare('youtube_profile', [/^https?:\/\/(www\.)?youtube\.com\/(user|channel)\/([^\/]+)/])
  end

  def youtube_profile_direct_attributes
    %w(
      comment_count
      country
      description
      title
      published_at
      subscriber_count
      video_count
      view_count
      thumbnails
    )
  end

  def data_from_youtube_profile
    channel = Yt::Channel.new url: self.url
    video_data = channel.snippet.data
    video_statistics = channel.statistics_set.data

    self.data[:raw][:api] = { id: channel.id }
    self.youtube_profile_direct_attributes.each do |attr|
      camel_attr = attr.camelize(:lower)
      self.data[:raw][:api][attr] = attr.match('count') ? video_statistics.dig(camel_attr) : video_data.dig(camel_attr)
    end

    self.data.merge!({
      external_id: data[:raw][:api][:id],
      title: self.data[:raw][:api][:title].to_s,
      description: self.data[:raw][:api][:description].to_s,
      published_at: self.data[:raw][:api][:published_at],
      picture: self.get_youtube_thumbnail,
      author_picture: self.get_youtube_thumbnail,
      country: self.data[:raw][:api][:country],
      username: self.get_youtube_username || '',
      subtype: self.get_youtube_subtype,
      author_name: self.data[:raw][:api][:title].to_s,
      # videos: self.parse_youtube_videos(channel.videos),
      playlists_count: channel.playlists.count,
      video_count: self.data[:raw][:api][:video_count].to_s,
      subscriber_count: self.data[:raw][:api][:subscriber_count].to_s
      # playlists: self.parse_youtube_playlists(channel.playlists)
    })
  end

  # def parse_youtube_playlists(playlists)
  #   i = 0
  #   list = []
  #   playlists.map do |p|
  #     i += 1
  #     list << {
  #       title: p.title,
  #       description: p.description,
  #       item_count: p.item_count,
  #       published_at: p.published_at,
  #       tags: p.tags,
  #       privacy_status: p.privacy_status
  #     } if i < 10
  #   end
  #   list
  # end

  # def parse_youtube_videos(videos)
  #   i = 0
  #   list = []
  #   videos.map do |v|
  #     i += 1
  #     list << {
  #       comment_count: v.comment_count,
  #       description: v.description,
  #       dislike_count: v.dislike_count,
  #       duration: v.duration,
  #       favorite_count: v.favorite_count,
  #       like_count: v.like_count,
  #       published_at: v.published_at,
  #       title: v.title,
  #       view_count: v.view_count,
  #       age_restricted: v.age_restricted?,
  #       belongs_to_closed_account: v.belongs_to_closed_account?,
  #       belongs_to_suspended_account: v.belongs_to_suspended_account?,
  #       claimed: v.claimed?,
  #       deleted: v.deleted?,
  #       duplicate: v.duplicate?,
  #       violates_terms_of_use: v.violates_terms_of_use?
  #     } if i < 10
  #   end
  #   list
  # end

  def get_youtube_username
    match = self.url.match(/^https?:\/\/(www\.)?youtube\.com\/user\/([^\/]+)/)
    username = match.nil? ? self.data[:raw][:api][:title].gsub(/[^a-zA-Z0-9]/, '') : match[2]
    username.downcase
  end

  def get_youtube_subtype
    match = self.url.match(/^https?:\/\/(www\.)?youtube\.com\/(user|channel)\/([^\/]+)/)
    match[2]
  end
end
