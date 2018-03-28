require 'pender_redis'

class SaveScreenshotWorker
  include Sidekiq::Worker
    
  def save(url, picture, settings, tab, script = '')
    t = Time.now.to_i.to_s
    tmp = Media.url_hash(url) + '-' + t + '.png'
    path = File.join(Rails.root, 'public', 'screenshots', Media.image_filename(url))
    output_file = File.join(Rails.root, 'public', 'screenshots', tmp)

    fetcher = Chromeshot::Screenshot.new debug_port: CONFIG['chrome_debug_port']

    Timeout::timeout(30) { fetcher.take_screenshot_from_tab(tab: tab, output: output_file, script: script) }

    dimensions = IO.read(output_file)[0x10..0x18].unpack('NN')
    dimensions[0] > 100 ? (FileUtils.rm_f(path) && FileUtils.ln_s(output_file, path)) : raise('Could not take screenshot')

    CcDeville.clear_cache_for_url(picture)
    
    data = { screenshot_url: picture + "?t=#{t}", screenshot_taken: 1 }
    Media.notify_webhook('screenshot', url, data, settings)
    
    Media.update_cache(url, { 'screenshot_taken' => 1, 'archives' => { 'screenshot' => data } })
  end

  def perform
    redis = PenderRedis.new.redis 
    job = redis.lpop('pender-screenshots-queue')
    unless job.nil?
      data = JSON.parse(job)
      begin self.save(data['url'], data['picture'], data['settings'], data['tab'], data['script']) rescue ScreenshotWorker.perform_async(data['url'], data['picture'], data['key_id'], data['script']) end
    end
  end
end
