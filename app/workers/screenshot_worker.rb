require 'pender_redis'

class ScreenshotWorker
  include Sidekiq::Worker
  sidekiq_options retry: 10

  def save_to_redis(data)
    redis = PenderRedis.new.redis
    redis.rpush('pender-screenshots-queue', data)
  end

  def perform(url, picture, key_id, script = '')
    saver = Chromeshot::Screenshot.new debug_port: CONFIG['chrome_debug_port']
    tab = saver.load_page_in_new_tab(url: url.gsub('%23', '#'))
    raise 'Could not open tab' if tab.blank?
    key = ApiKey.where(id: key_id).last
    settings = key ? key.application_settings.with_indifferent_access : {}
    self.save_to_redis({ url: url, picture: picture, settings: settings, tab: tab, key_id: key_id, script: script }.to_json)
  end
end
