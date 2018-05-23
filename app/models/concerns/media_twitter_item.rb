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
      self.data.merge!(error: { message: "#{error.class}: #{error.message}", code: error.code })
      return
    end
  end

  def data_from_twitter_item
    self.url = self.url.gsub(/(%23|#)!\//, '')
    self.replace_subdomain_pattern
    parts = self.url.match(URL)
    user, id = parts['user'], parts['id']
    handle_twitter_exceptions do
      self.data['raw']['api'] = self.twitter_client.status(id, tweet_mode: 'extended').as_json
      self.data.merge!({
        username: '@' + user,
        title: get_info_from_data('api', data, 'text', 'full_text').gsub(/\s+/, ' '),
        description: get_info_from_data('api', data, 'text', 'full_text'),
        picture: self.twitter_item_picture,
        author_picture: self.twitter_author_picture,
        published_at: self.data['raw']['api']['created_at'],
        html: html_for_twitter_item,
        author_name: self.data['raw']['api']['user']['name'],
        author_url: self.twitter_author_url(user) || top_url(self.url)
      })
    end
  end

  def twitter_author_picture
    self.data['raw']['api']['user']['profile_image_url_https'].gsub('_normal', '')
  end

  def twitter_item_picture
    unless self.data['raw']['api']['entities']['media'].nil?
      self.data['raw']['api']['entities']['media'][0]['media_url_https'] || self.data['raw']['api']['entities']['media'][0]['media_url']
    end
  end

  def html_for_twitter_item
    '<blockquote class="twitter-tweet">' +
    '<a href="' + self.url + '"></a>' +
    '</blockquote>' +
    '<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>'
  end

  def twitter_oembed_url
    "https://publish.twitter.com/oembed?url=#{self.url}"
  end

  def twitter_author_url(username)
    return if username.blank?
    begin
      self.twitter_client.user(username).url.to_s
    rescue Twitter::Error => e
      Rails.logger.info "[Twitter URL] Cannot get twitter url of #{username}: #{e.class} - #{e.message}"
      nil
    end
  end
end
