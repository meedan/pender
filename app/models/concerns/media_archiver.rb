require 'error_codes'
require 'pender_exceptions'

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
          self.send("archive_to_#{name}")
        end
      end
    end
  end

  def skip_archive_if_needed(archivers)
    return true if archivers.include?('none')
    url = self.url
    skip = PenderConfig.get('archiver_skip_hosts')
    unless skip.blank?
      host = begin URI.parse(url).host rescue '' end
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
      data = { error: { message: message, code: LapisConstants::ErrorCodes::const_get(error[:type]) }}
      self.data['archives'].merge!({"#{archiver}": data })
      Rails.logger.warn level: 'WARN', message: error[:type], url: self.url, archiver: archiver
      Media.notify_webhook_and_update_cache(archiver, url, data, ApiKey.current&.id)
    end
  end

  def filter_archivers(archivers)
    id = Media.get_id(original_url)
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
      PenderAirbrake.notify(StandardError.new(info[:error_message]), info.merge({ url: url, archiver: archiver, key_id: key_id }))
      Rails.logger.warn level: 'WARN', message: "[#{info[:error_class]}] #{info[:error_message]}", url: url, archiver: archiver
      data = { error: { message: info[:error_message], code: LapisConstants::ErrorCodes::const_get('ARCHIVER_FAILURE') }}
      Media.notify_webhook_and_update_cache(archiver, url, data, key_id)
    end

    def notify_webhook_and_update_cache(archiver, url, data, key_id)
      settings = Media.api_key_settings(key_id)
      Media.notify_webhook(archiver, url, data, settings)
      Media.update_cache(url, { archives: { archiver => data } })
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
      rescue Pender::RetryLater => error
        retry_archiving_after_failure(archiver, { message: error.message })
      rescue StandardError => error
        error_type = 'ARCHIVER_ERROR'
        params.merge!({code: LapisConstants::ErrorCodes::const_get(error_type), message: error.message})
        data = { error: { message: params[:message], code: LapisConstants::ErrorCodes::const_get(error_type) }}
        Media.notify_webhook_and_update_cache(archiver, params[:url], data, params[:key_id])
        retry_archiving_after_failure(archiver, params)
      end
    end

    def retry_archiving_after_failure(archiver, params)
      Rails.logger.warn level: 'WARN', message: "#{params[:message]}", url: params[:url], archiver: archiver, error_code: params[:code], error_message: params[:message]
      raise Pender::RetryLater, "[#{archiver}]: #{params[:message]}"
    end
  end

end
