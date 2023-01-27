require 'pender/store'

class MediaParserWorker
  include Sidekiq::Worker
  include MediasHelper

  def perform(url, key_id, refresh, archivers)
    key = ApiKey.where(id: key_id).first
    settings = key ? key.settings : {}

    type, data = is_url?(url) ? self.parse(url, key, refresh, archivers) : ['error', invalid_url_error]
    Media.notify_webhook(type, url, data, settings)
  end

  def parse(url, key, refresh, archivers)
    id = Media.get_id(url)
    ApiKey.current = key
    cached = Pender::Store.current.read(id, :json)
    data = {}
    type = 'media_parsed'
    media = nil
    return [type, cached] if !cached.nil? && !refresh
    begin
      return ['error', invalid_url_error] unless RequestHelper.validate_url(url)
      media = Media.new(url: url, key: key)
      data = media.as_json(force: refresh, archivers: archivers)
    rescue Net::ReadTimeout
      data = get_timeout_data(nil, url, id)
    rescue StandardError => e
      data = get_error_data({ message: e.message, code: 'UNKNOWN' }, media, url, id)
    end
    return [type, data]
  end

  def invalid_url_error
    { error: { message: 'The URL is not valid', code: Lapis::ErrorCodes::const_get('INVALID_VALUE') }}
  end
end

