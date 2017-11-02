class ScreenshotWorker
  include Sidekiq::Worker

  def perform(url, picture)
    filename = url.parameterize + '.png'
    tmp = url.parameterize + '-temp.png'
    path = File.join(Rails.root, 'public', 'screenshots', filename)
    output_file = File.join(Rails.root, 'public', 'screenshots', tmp)

    fetcher = Chromeshot::Screenshot.new debug_port: CONFIG['chrome_debug_port']
    fetcher.take_screenshot!(url: url, output: output_file)

    FileUtils.rm_f path
    File.exist?(output_file) ? FileUtils.mv(output_file, path) : FileUtils.ln_s(File.join(Rails.root, 'public', 'no_picture.png'), path)
    CcDeville.clear_cache_for_url(picture)
  end
end
