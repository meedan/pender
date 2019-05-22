require 'pender_exceptions'

module MediaTwitterItem
  extend ActiveSupport::Concern

  URL = /^https?:\/\/([^\.]+\.)?twitter\.com\/((%23|#)!\/)?(?<user>[^\/]+)\/status\/(?<id>[0-9]+).*/

  included do
    Media.declare('twitter_item', [URL])
  end

  def handle_twitter_exceptions
    begin
      yield
    rescue Twitter::Error::TooManyRequests => e
      raise Pender::ApiLimitReached.new(e.rate_limit.reset_in)
    rescue Twitter::Error => error
      Airbrake.notify(error, parameters: { url: self.url }) if Airbrake.configuration.api_key && !self.doc.nil?
      self.data.merge!(error: { message: "#{error.class}: #{error.message}", code: error.code })
      return
    end
  end

  def data_from_twitter_item
    self.url = self.url.gsub(/(%23|#)!\//, '')
    self.replace_subdomain_pattern
    parts = self.url.match(URL)
    user, id = parts['user'], parts['id']
    self.data['raw']['api'] = {}
    handle_twitter_exceptions do
      self.data['raw']['api'] = self.twitter_client.status(id, tweet_mode: 'extended').as_json
    end
    self.data.merge!({
      external_id: id,
      username: '@' + user,
      title: get_info_from_data('api', data, 'text', 'full_text').gsub(/\s+/, ' '),
      description: get_info_from_data('api', data, 'text', 'full_text'),
      picture: self.twitter_item_picture,
      author_picture: self.twitter_author_picture,
      published_at: get_info_from_data('api', data, 'created_at'),
      html: html_for_twitter_item,
      author_name: self.data.dig('raw', 'api', 'user', 'name'),
      author_url: self.twitter_author_url(user) || top_url(self.url)
    })
  end

  def twitter_author_picture
    picture_url = self.data.dig('raw', 'api', 'user', 'profile_image_url_https')
    picture_url.gsub('_normal', '') if picture_url
  end

  def twitter_item_picture
    item_media = self.data.dig('raw', 'api', 'entities', 'media')
    (item_media.dig(0, 'media_url_https') || item_media.dig(0, 'media_url')) if item_media
  end

  def html_for_twitter_item
    return '' if self.doc.nil?
    '<blockquote class="twitter-tweet">' +
    '<a href="' + self.url + '"></a>' +
    '</blockquote>' +
    '<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>'
  end

  def twitter_oembed_url
    "https://publish.twitter.com/oembed?url=#{self.url}"
  end

  def twitter_author_url(username)
    return if username.blank? || username == '@username'
    begin
      self.twitter_client.user(username).url.to_s
    rescue Twitter::Error => e
      Airbrake.notify(e, parameters: { url: self.url, username: username }) if Airbrake.configuration.api_key
      Rails.logger.info "[Twitter URL] Cannot get twitter url of #{username}: #{e.class} - #{e.message}"
      nil
    end
  end
end
