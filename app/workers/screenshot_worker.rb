class ScreenshotWorker
  include Sidekiq::Worker

  def clear_cache(url)
    if CONFIG['cc_deville_host'].present? && CONFIG['cc_deville_token'].present?
      cc = CcDeville.new(CONFIG['cc_deville_host'], CONFIG['cc_deville_token'], CONFIG['cc_deville_httpauth'])
      cc.clear_cache(url)
    end
  end

  def perform(url, picture)
    filename = url.parameterize + '.png'
    tmp = url.parameterize + '-temp.png'
    path = File.join(Rails.root, 'public', 'screenshots', filename)
    fetcher = Smartshot::Screenshot.new(window_size: [800, 600])
    output_file = File.join(Rails.root, 'public', 'screenshots', tmp)
    fetcher.take_screenshot! url: url, output: output_file, wait_for_element: ['body'], sleep: 10, frames_path: []
    FileUtils.rm_f path
    File.exist?(output_file) ? FileUtils.mv(output_file, path) : FileUtils.ln_s(File.join(Rails.root, 'public', 'no_picture.png'), path)
    self.clear_cache(picture)
  end
end
