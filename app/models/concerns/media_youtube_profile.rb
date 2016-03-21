module MediaYoutubeProfile
  extend ActiveSupport::Concern

  included do
    Media.declare('youtube_profile', [/^https?:\/\/(www\.)?youtube\.com\/user\/([^\/]+)$/])
  end

  def youtube_profile_attributes
    %w(
      title
      description
      published_at
      thumbnail_url
      view_count
      subscriber_count
      views
      uniques
      estimated_minutes_watched
      viewer_percentage
      comments
      likes
      dislikes
      shares
      subscribers_gained
      subscribers_lost
      favorites_added
      favorites_removed
      videos_added_to_playlists
      videos_removed_from_playlists
      average_view_duration
      average_view_percentage
      annotation_clicks
      annotation_click_through_rate
      annotation_close_rate
      earnings
      impressions
      monetized_playbacks
      playback_based_cpm
      comment_count
      subscriber_count
    )
  end

  def data_from_youtube_profile
    channel = Yt::Channel.new url: self.url
    data = {}
    self.youtube_profile_attributes.each do |attr|
      begin
        data[attr] = channel.send(attr)
      rescue
        # This field is private
      end
    end
    self.data = data
  end
end 
