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
    self.data[:raw] ||= {}
    self.data[:raw][:api] = {}

    handle_youtube_exceptions do
      Yt.configuration.api_key = PenderConfig.get(:google_api_key)
      channel = Yt::Channel.new url: self.url
      video_data = channel.snippet.data
      video_statistics = channel.statistics_set.data

      self.data[:raw][:api][:id] = channel.id
      self.youtube_profile_direct_attributes.each do |attr|
        camel_attr = attr.camelize(:lower)
        self.data[:raw][:api][attr] = attr.match('count') ? video_statistics.dig(camel_attr) : video_data.dig(camel_attr)
      end
      self.set_data_field('playlists_count', channel.playlists.count)
      self.set_data_field('country', get_info_from_data('api', data, 'country'))
      self.set_data_field('video_count', get_info_from_data('api', data, 'video_count'))
      self.set_data_field('subscriber_count', get_info_from_data('api', data, 'subscriber_count'))
    end

    self.set_data_field('external_id', get_info_from_data('api', data, 'id'), get_youtube_channel_id)
    metadata = self.get_opengraph_metadata || {}
    self.set_data_field('title', get_info_from_data('api', data, 'title'), metadata.dig('title'))
    self.set_data_field('description', get_info_from_data('api', data, 'description'), metadata.dig('description'))
    self.set_data_field('picture', self.get_youtube_thumbnail, metadata.dig('picture'))
    self.set_data_field('username', self.get_youtube_username)
    self.set_data_field('published_at', get_info_from_data('api', data, 'published_at'))
    self.set_data_field('author_picture', self.data[:picture])
    self.set_data_field('author_name', self.data[:title])
    self.set_data_field('subtype', self.get_youtube_subtype)
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
    username = match.nil? ? self.data[:title].gsub(/[^a-zA-Z0-9]/, '') : match[2]
    username.downcase
  end

  def get_youtube_channel_id
    match = self.url.match(/^https?:\/\/(www\.)?youtube\.com\/channel\/([^\/]+)/)
    match[2] if match
  end

  def get_youtube_subtype
    match = self.url.match(/^https?:\/\/(www\.)?youtube\.com\/(user|channel)\/([^\/]+)/)
    match[2]
  end

  def handle_youtube_exceptions
    begin
      yield
    rescue Yt::Errors::NoItems => e
      self.set_youtube_item_deleted_info(e)
    rescue Yt::Errors::Forbidden => e
      self.data[:raw][:api] = { error: { message: e.message, code: LapisConstants::ErrorCodes::const_get('UNAUTHORIZED') }}
    end
  end
end
