require 'pender_redis'

class SaveScreenshotWorker
  include Sidekiq::Worker
    
  def save(url, picture, settings, tab)
    filename = url.parameterize + '.png'
    tmp = url.parameterize + '-temp.png'
    path = File.join(Rails.root, 'public', 'screenshots', filename)
    output_file = File.join(Rails.root, 'public', 'screenshots', tmp)

    fetcher = Chromeshot::Screenshot.new debug_port: CONFIG['chrome_debug_port']

    Timeout::timeout(30) { fetcher.take_screenshot_from_tab(tab: tab, output: output_file) }

    FileUtils.rm_f path
    File.exist?(output_file) ? FileUtils.mv(output_file, path) : raise('Could not take screenshot')

    CcDeville.clear_cache_for_url(picture)
    
    data = { screenshot_url: picture, screenshot_taken: 1 }
    Media.notify_webhook('screenshot', url, data, settings)
    
    Media.update_cache(url, { 'screenshot_taken' => 1, 'archives' => { 'screenshot' => data } })
  end

  def perform
    redis = PenderRedis.new.redis 
    job = redis.lpop('pender-screenshots-queue')
    unless job.nil?
      data = JSON.parse(job)
      begin self.save(data['url'], data['picture'], data['settings'], data['tab']) rescue ScreenshotWorker.perform_async(data['url'], data['picture'], data['key_id']) end
    end
  end
end
