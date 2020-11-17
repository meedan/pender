class CcDeville
  def self.clear_cache_for_url(url)
    if PenderConfig.get('cloudflare_auth_email')
      # https://api.cloudflare.com/#zone-purge-files-by-url
      uri = URI("https://api.cloudflare.com/client/v4/zones/#{PenderConfig.get('cloudflare_zone')}/purge_cache")
      req = Net::HTTP::Post.new(uri.path)
      req['X-Auth-Email'] = PenderConfig.get('cloudflare_auth_email')
      req['X-Auth-Key'] = PenderConfig.get('cloudflare_auth_key')
      req['Content-Type'] = 'application/json'
      req.body = {
        'files': [url]
      }.to_json
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = uri.scheme == 'https'
      begin
        res = JSON.parse(http.request(req).body)
        raise StandardError.new "#{res['errors'][0]['code']} #{res['errors'][0]['message']}" if !res['success']
      rescue StandardError => e
        Rails.logger.error "[Cloudflare] #{e.message}"
        PenderAirbrake.notify(e, params: { url: url })
      end
    end
  end
end
