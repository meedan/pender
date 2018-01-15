module MediaArchiver
  extend ActiveSupport::Concern

  ARCHIVERS = {}

  def archive
    url = self.url
    self.skip_archive_if_needed and return

    ARCHIVERS.each do |name, rule|
      rule[:patterns].each do |pattern|
        if (rule[:modifier] == :only && !pattern.match(url).nil?) || (rule[:modifier] == :except && pattern.match(url).nil?)
          self.send("archive_to_#{name}")
        end
      end
    end
  end

  def skip_archive_if_needed
    url = self.url
    skip = CONFIG['archiver_skip_hosts']
    unless skip.blank?
      host = begin URI.parse(url).host rescue '' end
      return true if skip.split(',').include?(host)
    end
    false
  end

  module ClassMethods
    def declare_archiver(name, patterns, modifier)
      ARCHIVERS[name] = { patterns: patterns, modifier: modifier }
    end

    def update_cache(url, newdata)
      id = Media.get_id(url)
      data = Rails.cache.read(id)
      unless data.blank?
        newdata.each { |key, value| data[key] = value }
        data['webhook_called'] = @webhook_called ? 1 : 0
        Rails.cache.write(id, data)
      end
    end

    def notify_webhook(url, data, settings)
      if settings['webhook_url'] && settings['webhook_token']
        uri = URI.parse(settings['webhook_url'])
        payload = data.merge({ url: url }).to_json
        sig = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), settings['webhook_token'], payload)
        headers = { 'Content-Type': 'text/json', 'X-Signature': sig }
        http = Net::HTTP.new(uri.host, uri.port)
        request = Net::HTTP::Post.new(uri.request_uri, headers)
        request.body = payload
        http.request(request)
        @webhook_called = true
      end
    end
  end
end
