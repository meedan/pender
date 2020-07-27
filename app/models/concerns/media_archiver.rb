require 'error_codes'

module MediaArchiver
  extend ActiveSupport::Concern

  ARCHIVERS = {}

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
    skip = CONFIG['archiver_skip_hosts']
    unless skip.blank?
      host = begin URI.parse(url).host rescue '' end
      update_data_with_archivers_errors(archivers, { type: 'ARCHIVER_HOST_SKIPPED', info: host }) and return true if skip.split(',').include?(host)
    end
    false
  end

  def update_data_with_archivers_errors(archivers, error)
    return if archivers.empty?
    self.data['archives'] ||= {}
    key_id = self.key ? self.key.id : nil
    archivers.each do |archiver|
      message = if error[:info]
                  I18n.t(error[:type].downcase.to_sym, info: error[:info])
                else
                  I18n.t(error[:type].downcase.to_sym)
                end
      data = { error: { message: message, code: LapisConstants::ErrorCodes::const_get(error[:type]) }}
      self.data['archives'].merge!({"#{archiver}": data })
      Rails.logger.warn level: 'WARN', message: error[:type], url: self.url, archiver: archiver
      Media.notify_webhook_and_update_cache(archiver, url, data, key_id)
    end
  end

  def filter_archivers(archivers)
    id = Media.get_id(url)
    data = Pender::Store.read(id, :json)
    return archivers if data.nil? || data.dig(:archives).nil?
    archivers - data[:archives].keys
  end

  module ClassMethods
    def declare_archiver(name, patterns, modifier, enabled = true)
      ARCHIVERS[name] = { patterns: patterns, modifier: modifier, enabled: enabled }
    end

    def give_up(archiver, url, key_id, attempts, response = {})
      if attempts > 20
        error_type = response[:error_type] || 'ARCHIVER_FAILURE'
        Airbrake.notify(StandardError.new(error_type), url: url, archiver: archiver, error_code: response[:code], error_message: response[:message]) if Airbrake.configured?
        Rails.logger.warn level: 'WARN', message: "[#{error_type}] #{response[:message]}", url: url, archiver: archiver, error_code: response[:code], error_message: response[:message]
        data = { error: { message: I18n.t(:archiver_failure, message: response[:message], code: response[:code]), code: LapisConstants::ErrorCodes::const_get(error_type) }}
        Media.notify_webhook_and_update_cache(archiver, url, data, key_id)
        return true
      end
      false
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

    def enabled_archivers(archivers, media = nil)
      enabled = ARCHIVERS.select { |name, rule| archivers.include?(name) && rule[:enabled]}
      media.update_data_with_archivers_errors(archivers - enabled.keys, { type: 'ARCHIVER_DISABLED' }) if media
      enabled
    end

    def url_hash(url)
      ## Screenshots are disabled
      # Digest::MD5.hexdigest(url.parameterize)
    end

    def image_filename(url)
      ## Screenshots are disabled
      # url_hash(url) + '.png'
    end

    def handle_archiving_exceptions(archiver, delay_time, params)
      begin
        yield
      rescue StandardError => error
        error_type = 'ARCHIVER_ERROR'
        params.merge!({code: LapisConstants::ErrorCodes::const_get(error_type), message: "#{error.class} #{error.message}"})
        retry_archiving_after_failure(error_type, archiver, delay_time, params)
        data = { error: { message: params[:message], code: LapisConstants::ErrorCodes::const_get(error_type) }}
        Media.notify_webhook_and_update_cache(archiver, params[:url], data, params[:key_id])
        return
      end
    end

    def retry_archiving_after_failure(error_type, archiver, delay_time, params)
      Rails.logger.warn level: 'WARN', message: "[#{error_type}] #{params[:message]}", url: params[:url], archiver: archiver, error_code: params[:code], error_message: params[:message], attempts: params[:attempts]
      Media.delay_for(delay_time).send("send_to_#{archiver}", params[:url], params[:key_id], params[:attempts] + 1, {code: params[:code], message: params[:message]}, params[:supported])
    end
  end

end
