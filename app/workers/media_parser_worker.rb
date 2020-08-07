require 'timeout'
require 'pender_store'

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
    cached = Pender::Store.current.read(id, :json)
    data = {}
    type = 'media_parsed'
    media = nil
    return [type, cached] if !cached.nil? && !refresh
    begin
      Timeout::timeout(timeout_value) do
        return ['error', invalid_url_error] unless Media.validate_url(url)
        media = Media.new(url: url, key: key)
        data = media.as_json(force: refresh, archivers: archivers)
      end
    rescue Timeout::Error
      data = get_timeout_data(nil, url, id)
    rescue StandardError => e
      data = get_error_data({ message: e.message, code: LapisConstants::ErrorCodes::const_get('UNKNOWN') }, media, url, id)
    end
    return [type, data]
  end

  def invalid_url_error
    { error: { message: I18n.t(:url_not_valid), code: LapisConstants::ErrorCodes::const_get('INVALID_VALUE') }}
  end
end

