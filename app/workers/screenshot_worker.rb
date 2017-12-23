class ScreenshotWorker
  include Sidekiq::Worker
  sidekiq_options retry: 10

  def start_chromeshot_if_not_running
    port = CONFIG['chrome_debug_port'] || 9555
    while !system("lsof -i:#{port}", out: '/dev/null')
      Chromeshot::Screenshot.setup_chromeshot(port) 
      sleep 10
    end
  end

  def save_to_redis(data)
    redis = SIDEKIQ_CONFIG.nil? ? Redis.new : Redis.new({ host: SIDEKIQ_CONFIG[:redis_host], port: SIDEKIQ_CONFIG[:redis_port], db: SIDEKIQ_CONFIG[:redis_database] })
    redis.rpush('pender-screenshots-queue', data)
  end

  def perform(url, picture, key_id)
    start_chromeshot_if_not_running
    saver = Chromeshot::Screenshot.new debug_port: CONFIG['chrome_debug_port']
    tab = saver.load_page_in_new_tab(url: url)
    raise 'Could not open tab' if tab.blank?
    self.save_to_redis({ url: url, picture: picture, key_id: key_id, tab: tab }.to_json)
  end
end
