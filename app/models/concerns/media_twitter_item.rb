require 'pender_exceptions'

module MediaTwitterItem
  extend ActiveSupport::Concern

  URL = /^https?:\/\/([^\.]+\.)?twitter\.com\/([^\/]+)\/status\/([0-9]+).*/

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
    parts = self.url.match(URL)
    user, id = parts[2], parts[3]

    handle_twitter_exceptions do
      self.data.merge!(self.twitter_client.status(id).as_json)
      self.data.merge!({
        username: user,
        title: self.data['text'].gsub(/\s+/, ' '),
        description: self.data['text'],
        picture: self.data['user']['profile_image_url_https'].gsub('_normal', ''),
        published_at: self.data['created_at'],
        html: html_for_twitter_item,
        author_url: 'https://twitter.com/' + user
      })
    end
  end

  def html_for_twitter_item
    '<blockquote class="twitter-tweet">' +
    '<a href="' + self.url + '"></a>' +
    '</blockquote>' +
    '<script async src="//platform.twitter.com/widgets.js" charset="utf-8"></script>'
  end
end
