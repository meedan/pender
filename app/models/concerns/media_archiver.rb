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
        data = { error: { message: I18n.t(:could_not_archive, error_message: response[:message]), code: response[:code] }}
        Media.notify_webhook_and_update_cache(archiver, url, data, key_id)
        return true
      end

      false
    end

    def api_key_settings(key_id)
      key = ApiKey.where(id: key_id).last
      key ? key.application_settings.with_indifferent_access : {}
    end

    def notify_webhook_and_update_cache(archiver, url, data, key_id)
      settings = Media.api_key_settings(key_id)
      Media.notify_webhook(archiver, url, data, settings)
      Media.update_cache(url, { archives: { archiver => data } })
    end

    def update_cache(url, newdata)
      id = Media.get_id(url)
      data = Pender::Store.read(id, :json)
      unless data.blank?
        newdata.each do |key, value|
          data[key] = data[key].is_a?(Hash) ? data[key].merge(value) : value
        end
        data['webhook_called'] = @webhook_called ? 1 : 0
        Pender::Store.write(id, :json, data)
      end
    end

    def notify_webhook(type, url, data, settings)
      if settings['webhook_url'] && settings['webhook_token']
        uri = URI.parse(settings['webhook_url'])
        payload = data.merge({ url: url, type: type }).to_json
        sig = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), settings['webhook_token'], payload)
        headers = { 'Content-Type': 'text/json', 'X-Signature': sig }
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        request = Net::HTTP::Post.new(uri.request_uri, headers)
        request.body = payload
        response = http.request(request)
        Rails.logger.info "[Webhook] Sending #{url} to webhook: Code: #{response.code} Response: #{response.body}"
        @webhook_called = true
      end
      true
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
  end
end
