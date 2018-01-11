module MediaScreenshot
  extend ActiveSupport::Concern

  def screenshot_path
    base_url = CONFIG['public_url'] || self.request.base_url
    filename = self.url.parameterize + '.png'
    URI.join(base_url, 'screenshots/', filename).to_s
  end

  def generate_screenshot
    url = self.url
    picture = self.screenshot_path
    filename = self.url.parameterize + '.png'
    path = File.join(Rails.root, 'public', 'screenshots', filename)
    FileUtils.rm_f path
    FileUtils.ln_s File.join(Rails.root, 'public', 'pending_picture.png'), path
    self.data['screenshot'] = picture
    self.data['screenshot_taken'] = 0
    key_id = self.key ? self.key.id : nil
    ScreenshotWorker.perform_async(url, picture, key_id)
  end
end
