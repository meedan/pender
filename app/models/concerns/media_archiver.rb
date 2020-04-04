module MediaArchiver
  extend ActiveSupport::Concern

  ARCHIVERS = {}

  def archive(archivers = nil)
    url = self.url
    self.skip_archive_if_needed(archivers) and return
    archivers = self.filter_archivers(archivers)

    Media.enabled_archivers(*archivers).each do |name, rule|
      rule[:patterns].each do |pattern|
        if (rule[:modifier] == :only && !pattern.match(url).nil?) || (rule[:modifier] == :except && pattern.match(url).nil?)
          self.send("archive_to_#{name}")
        end
      end
    end
  end

  def skip_archive_if_needed(archivers)
    return true if archivers == 'none'
    url = self.url
    skip = CONFIG['archiver_skip_hosts']
    unless skip.blank?
      host = begin URI.parse(url).host rescue '' end
      return true if skip.split(',').include?(host)
    end
    false
  end

  def filter_archivers(archivers)
    archivers = archivers.nil? ? ARCHIVERS.keys : archivers.split(',').map(&:strip)
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
        Airbrake.notify(StandardError.new('Could not archive'), url: url, archiver: archiver, error_code: response[:code], error_message: response[:message]) if Airbrake.configured?
        Rails.logger.warn level: 'WARN', messsage: '[Archiver] Could not archive', url: url, archiver: archiver, error_code: response[:code], error_message: response[:message]
        data = { error: { message: I18n.t(:could_not_archive, error_message: response[:message]), code: response[:code] }}
        Media.notify_webhook_and_update_cache(archiver, url, data, key_id)
        return true
      end

      false
    end

    def api_key_settings(key_id)
      key = ApiKey.where(id: key_id).last
      key && key.application_settings ? key.application_settings.with_indifferent_access : {}
    end

    def notify_webhook_and_update_cache(archiver, url, data, key_id)
      settings = Media.api_key_settings(key_id)
      Media.notify_webhook(archiver, url, data, settings)
      Media.update_cache(url, { archives: { archiver => data } })
    end

    def enabled_archivers(*archivers)
      ARCHIVERS.slice(*archivers).select { |_name, rule| rule[:enabled] }
    end

    def url_hash(url)
      ## Screenshots are disabled
      # Digest::MD5.hexdigest(url.parameterize)
    end

    def image_filename(url)
      ## Screenshots are disabled
      # url_hash(url) + '.png'
    end

    def handle_archiving_exceptions(archiver, delay_time, url, key_id, attempts, supported = nil)
      begin
        yield
      rescue StandardError => error
        Media.delay_for(delay_time).send("send_to_#{archiver}", url, key_id, attempts + 1, {code: 5, message: error.message}, supported)
        Rails.logger.warn level: 'WARN', messsage: '[Archiver] Error archiving', url: url, archiver: archiver, error_class: error.class, error_message: error.message
        data = { error: { message: I18n.t(:could_not_archive, error_message: error.message), code: 5 }}
        Media.notify_webhook_and_update_cache(archiver, url, data, key_id)
        return
      end
    end
  end

end
