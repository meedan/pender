require 'timeout'

class MediaParserWorker
  include Sidekiq::Worker
  include MediasHelper

  def perform(url, key_id, refresh, archivers)
    key = ApiKey.where(id: key_id).first
    settings = key ? key.application_settings.with_indifferent_access : {}
    if is_url?(url)
      type, data = self.parse(url, key, refresh, archivers)
    else
      type = 'error'
      data = { error: { message: I18n.t(:url_not_valid), code: LapisConstants::ErrorCodes::const_get('INVALID_VALUE') }}
    end
    Media.notify_webhook(type, url, data, settings)
  end

  def parse(url, key, refresh, archivers)
    id = Media.get_id(url)
    cached = Rails.cache.read(id)
    type = 'media_parsed'
    data = {}
    return [type, cached] if !cached.nil? && !refresh
    begin
      Timeout::timeout(timeout_value) do
        return ['error', {error: { message: I18n.t(:url_not_valid), code: LapisConstants::ErrorCodes::const_get('INVALID_VALUE') }}] unless Media.validate_url(url)
        media = Media.new(url: url, key: key)
        data = media.as_json(force: refresh, archivers: archivers)
      end
    rescue Timeout::Error
      data = get_timeout_data(nil, url, id)
    end
    return [type, data]
  end
end

