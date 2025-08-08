require 'lapis/error_codes'
require 'pender/exception'

module MediaArchiver
  extend ActiveSupport::Concern

  ARCHIVERS = {}
  ENABLED_ARCHIVERS = []

  def archive(archivers = nil)
    url = self.url
    archivers = archivers.to_s.split(',').map(&:strip)
    archivers = self.filter_archivers(archivers)
    self.skip_archive_if_needed(archivers) and return
    available = Media.available_archivers(archivers, self)
    Media.enabled_archivers(available, self).each do |name, rule|
      rule[:patterns].each do |pattern|
        if (rule[:modifier] == :only && !pattern.match(url).nil?) || (rule[:modifier] == :except && pattern.match(url).nil?)
          Rails.logger.info level: 'INFO', message: '[Archiver] Archiving new URL', url: url, archiver: name
          self.public_send("archive_to_#{name}", url, ApiKey.current&.id)
        end
      end
    end
  end

  def skip_archive_if_needed(archivers)
    return true if archivers.include?('none')
    url = self.url
    skip = PenderConfig.get('archiver_skip_hosts')
    unless skip.blank?
      host = begin RequestHelper.parse_url(url).host rescue '' end
      update_data_with_archivers_errors(archivers, { type: 'ARCHIVER_HOST_SKIPPED', info: host }) and return true if skip.split(',').include?(host)
    end
    false
  end

  def update_data_with_archivers_errors(archivers, error)
    return if archivers.empty?
    self.data['archives'] ||= {}
    archivers.each do |archiver|
      message = error[:type].titleize
      message += ": #{error[:info]}" if error[:info]
      data = { error: { message: message, code: Lapis::ErrorCodes::const_get(error[:type]) }}
      self.data['archives'].merge!({"#{archiver}": data })
      Rails.logger.warn level: 'WARN', message: error[:type], url: self.url, archiver: archiver
      Media.notify_webhook_and_update_cache(archiver, url, data, ApiKey.current&.id)
    end
  end

  def filter_archivers(archivers)
    id = Media.cache_key(self.url)
    data = Pender::Store.current.read(id, :json)
    return archivers if data.nil? || data.dig(:archives).nil?
    archivers - data[:archives].keys
  end

  module ClassMethods
    def declare_archiver(name, patterns, modifier, enabled = true)
      ARCHIVERS[name] = { patterns: patterns, modifier: modifier, enabled: enabled }
      ENABLED_ARCHIVERS << { key: name, label: name.tr('_', '.').capitalize } if enabled
    end

    def give_up(info = {})
      url, archiver, key_id = info[:args][0], info[:args][1], info[:args][2]
      Rails.logger.warn level: 'WARN', message: "[#{info[:error_class]}] #{info[:error_message]}", url: url, archiver: archiver
      data = { error: { message: info[:error_message], code: Lapis::ErrorCodes::const_get('ARCHIVER_FAILURE') }}
      Media.notify_webhook_and_update_cache(archiver, url, data, key_id)
    end

    def notify_webhook_and_update_cache(archiver, url, data, key_id)
      settings = Media.api_key_settings(key_id)

      id = Media.cache_key(url)
      archiver_data = Pender::Store.current.read(id, :json).to_h.dig('archives', archiver).to_h
      archiver_data.delete('error')
      Media.update_cache(url, { archives: { archiver => archiver_data.merge(data) } })
      Media.notify_webhook(archiver, url, data, settings)
    end

    def available_archivers(archivers, media = nil)
      available = ARCHIVERS.keys & archivers
      media.update_data_with_archivers_errors(archivers - available, { type: 'ARCHIVER_NOT_FOUND' }) if media
      available
    end

    def enabled_archivers(archivers = Media::ARCHIVERS.keys, media = nil)
      enabled_keys = Media::ENABLED_ARCHIVERS.select { |archiver| archivers.include?(archiver[:key]) }.map { |a| a[:key]}
      media.update_data_with_archivers_errors(archivers - enabled_keys, { type: 'ARCHIVER_DISABLED' }) if media
      ARCHIVERS.select {|name, _rule| enabled_keys.include?(name)}
    end

    def handle_archiving_exceptions(archiver, params)
      begin
        ApiKey.current = ApiKey.find_by(id: params.dig(:key_id))
        yield
      rescue Pender::Exception::RetryLater => error
        retry_archiving_after_failure(archiver, { message: error.message })
      rescue Pender::Exception::BlockedUrl,
             Pender::Exception::TooManyCaptures,
             Pender::Exception::ItemNotAvailable,
             Pender::Exception::RateLimitExceeded,
             JSON::ParserError => error
              post_error_tasks(archiver, params, error)
      rescue StandardError => error
        post_error_tasks(archiver, params, error, false)
        retry_archiving_after_failure(archiver, params)
      end
    end

    def post_error_tasks(archiver, params, error, notify_sentry = true)
      error_type = 'ARCHIVER_ERROR'
      if notify_sentry then Media.notify_sentry(archiver, params[:url], error) end
      data = Media.updated_errored_data(archiver, params, error, error_type = 'ARCHIVER_ERROR')
      Media.notify_webhook_and_update_cache(archiver, params[:url], data, params[:key_id])
    end

    def notify_sentry(archiver, url, error)
      PenderSentry.notify(
        error.class.new("#{archiver}: #{error.message}"),
        url: url,
        response_body: error.message
      )
    end

    def updated_errored_data(archiver, params, error, error_type = 'ARCHIVER_ERROR')
      params.merge!({code: Lapis::ErrorCodes::const_get(error_type), message: error.message})
      { error: { message: params[:message], code: Lapis::ErrorCodes::const_get(error_type) }}
    end

    def retry_archiving_after_failure(archiver, params)
      Rails.logger.warn level: 'WARN', message: "#{params[:message]}", url: params[:url], archiver: archiver, error_code: params[:code], error_message: params[:message]
      raise Pender::Exception::RetryLater, "[#{archiver}]: #{params[:message]}"
    end
  end
end
