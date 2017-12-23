class SaveScreenshotWorker
  include Sidekiq::Worker

  def update_cache(url)
    id = Media.get_id(url)
    data = Rails.cache.read(id)
    unless data.blank?
      data['screenshot_taken'] = 1
      Rails.cache.write(id, data)
    end
  end

  def notify_webhook(url, picture, key)
    settings = key.application_settings.with_indifferent_access

    if settings['webhook_url'] && settings['webhook_token']
      uri = URI.parse(settings['webhook_url'])
      payload = { screenshot_url: picture, screenshot_taken: 1, url: url }.to_json
      sig = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), settings['webhook_token'], payload)
      headers = { 'Content-Type': 'text/json', 'X-Signature': sig }
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri.request_uri, headers)
      request.body = payload
      response = http.request(request)
    end
  end
    
  def save(url, picture, key_id, tab)
    key = ApiKey.where(id: key_id).last
    filename = url.parameterize + '.png'
    tmp = url.parameterize + '-temp.png'
    path = File.join(Rails.root, 'public', 'screenshots', filename)
    output_file = File.join(Rails.root, 'public', 'screenshots', tmp)

    fetcher = Chromeshot::Screenshot.new debug_port: CONFIG['chrome_debug_port']

    Timeout::timeout(30) { fetcher.take_screenshot_from_tab(tab: tab, output: output_file) }

    FileUtils.rm_f path
    File.exist?(output_file) ? FileUtils.mv(output_file, path) : raise('Could not take screenshot')

    CcDeville.clear_cache_for_url(picture)

    self.update_cache(url)

    self.notify_webhook(url, picture, key) unless key.nil?
  end

  def perform
    redis = SIDEKIQ_CONFIG.nil? ? Redis.new : Redis.new({ host: SIDEKIQ_CONFIG[:redis_host], port: SIDEKIQ_CONFIG[:redis_port], db: SIDEKIQ_CONFIG[:redis_database] })
    job = redis.lpop('pender-screenshots-queue')
    unless job.nil?
      data = JSON.parse(job)
      begin
        self.save(data['url'], data['picture'], data['key_id'], data['tab'])
      rescue
        ScreenshotWorker.perform_async(data['url'], data['picture'], data['key_id'])
      end
    end
  end
end
