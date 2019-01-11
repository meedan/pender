module MediaScreenshotArchiver
  extend ActiveSupport::Concern

  def screenshot_script=(script)
    ## Screenshots are disabled
    # @screenshot_script = script
  end

  def screenshot_script
    ## Screenshots are disabled
    # @screenshot_script
  end

  def screenshot_path
    ## Screenshots are disabled
    # base_url = CONFIG['public_url'] || self.request.base_url
    # URI.join(base_url, 'screenshots/', Media.image_filename(self.url)).to_s
  end

  def archive_to_screenshot
    ## Screenshots are disabled
    # url = self.url
    # picture = self.screenshot_path
    # path = File.join(Rails.root, 'public', 'screenshots', Media.image_filename(url))
    # FileUtils.ln_sf File.join(Rails.root, 'public', 'pending_picture.png'), path
    # self.data['screenshot'] = picture
    # self.data['screenshot_taken'] = 0
    # key_id = self.key ? self.key.id : nil
    # ScreenshotWorker.perform_async(url, picture, key_id, self.screenshot_script)
  end
end
