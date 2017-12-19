class ScreenshotWorker
  include Sidekiq::Worker
  sidekiq_options retry: 10

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
    
  def start_chromeshot_if_not_running
    port = CONFIG['chrome_debug_port'] || 9555
    while !system("lsof -i:#{port}", out: '/dev/null')
      Chromeshot::Screenshot.setup_chromeshot(port) 
      sleep 10
    end
  end

  def perform(url, picture, key_id)
    key = ApiKey.where(id: key_id).last
    filename = url.parameterize + '.png'
    tmp = url.parameterize + '-temp.png'
    path = File.join(Rails.root, 'public', 'screenshots', filename)
    output_file = File.join(Rails.root, 'public', 'screenshots', tmp)

    start_chromeshot_if_not_running
    fetcher = Chromeshot::Screenshot.new debug_port: CONFIG['chrome_debug_port']
    fetcher.take_screenshot!(url: url, output: output_file)

    FileUtils.rm_f path
    File.exist?(output_file) ? FileUtils.mv(output_file, path) : raise('Could not take screenshow now, will retry later')

    CcDeville.clear_cache_for_url(picture)

    self.update_cache(url)

    self.notify_webhook(url, picture, key) unless key.nil?
  end
end
