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

  def text_from_twitter_item
    self.data['raw']['api']['text'] || self.data['raw']['api']['full_text'] || ''
  end

  def data_from_twitter_item
    self.url = self.url.gsub(/(%23|#)!\//, '')
    parts = self.url.match(URL)
    user, id = parts['user'], parts['id']
    handle_twitter_exceptions do
      self.data['raw']['api'] = self.twitter_client.status(id, tweet_mode: 'extended').as_json
      self.data.merge!({
        username: '@' + user,
        title: self.text_from_twitter_item.gsub(/\s+/, ' '),
        description: self.text_from_twitter_item,
        picture: self.twitter_item_picture,
        author_picture: self.twitter_item_picture,
        published_at: self.data['raw']['api']['created_at'],
        html: html_for_twitter_item,
        author_name: self.data['raw']['api']['user']['name'],
        author_url: 'https://twitter.com/' + user
      })
    end
  end

  def twitter_item_picture
    self.data['raw']['api']['user']['profile_image_url_https'].gsub('_normal', '')
  end

  def html_for_twitter_item
    '<blockquote class="twitter-tweet">' +
    '<a href="' + self.url + '"></a>' +
    '</blockquote>' +
    '<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>'
  end
end
