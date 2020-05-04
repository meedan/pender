module MediaVideoArchiver
  extend ActiveSupport::Concern

  included do
    Media.declare_archiver('video', [/^.*$/], :only)
  end

  def archive_to_video
    key_id = self.key ? self.key.id : nil
    self.class.archive_video_in_background(self.url, key_id)
  end

  module ClassMethods
    def archive_video_in_background(url, key_id)
      self.delay_for(15.seconds).send_to_video_archiver(url, key_id)
    end

    def send_to_video_archiver(url, key_id, attempts = 1, response = nil, supported = nil)
      handle_archiving_exceptions('video_archiver', 1.hour, { url: url, key_id: key_id, attempts: attempts, supported: supported }) do
        supported = supported_video?(url, key_id) if supported.nil?
        return if supported.is_a?(FalseClass) || notify_video_already_archived(url, key_id)
        id = Media.get_id(url)
        local_folder = File.join(Rails.root, 'tmp', 'videos', id)
        Media.give_up('video_archiver', url, key_id, attempts, response) and return
        uri = URI.encode(url)
        proxy = "--proxy=#{Media.yt_download_proxy(uri)}"
        output = "-o#{local_folder}/#{id}.%(ext)s"
        _stdout, stderr, status = Open3.capture3('youtube-dl', uri, proxy, output, '--restrict-filenames', '--no-warnings', '-q', '--write-all-thumbnails', '--write-info-json', '--all-subs', '-fogg/mp4/webm')

        if status.success?
          Media.store_video_folder(url, local_folder, self.archiving_folder, key_id)
        else
          retry_archiving_after_failure('ARCHIVER_FAILURE', 'video_archiver', 5.minutes, { url: url, key_id: key_id, attempts: attempts, code: status.exitstatus, message: stderr.gsub(/\n$/, ''), supported: supported })
        end
      end
    end

    def archiving_folder
      CONFIG.dig('storage', 'video_asset_path') || "#{CONFIG.dig('storage', 'endpoint')}/#{Pender::Store.video_bucket_name}/video"
    end

    def notify_video_already_archived(url, key_id)
      id = Media.get_id(url)
      data = Pender::Store.read(id, :json)
      return if data.nil? || data.dig(:archives, :video_archiver, :location).nil?
      settings = Media.api_key_settings(key_id)
      Media.notify_webhook('video_archiver', url, data, settings)
    end

    def supported_video?(url, key_id = nil)
      uri = URI.encode url
      proxy = "--proxy=#{Media.yt_download_proxy(uri)}"
      _stdout, stderr, status = Open3.capture3('youtube-dl', uri, proxy, '--restrict-filenames', '--no-warnings', '-g', '-q')
      unless status.success?
        data = { error: { message: "#{status.exitstatus} #{stderr.gsub(/;.*\n$/, '')}", code: LapisConstants::ErrorCodes::const_get('ARCHIVER_NOT_SUPPORTED_MEDIA') }}
        Media.notify_webhook_and_update_cache('video_archiver', url, data, key_id)
      end
      status.success?
    end

    def yt_download_proxy(url)
      uri = URI.parse(url)
      return unless uri.host.match(/youtube\.com/)
      ['proxy_host', 'proxy_port', 'proxy_pass', 'proxy_user_prefix'].each { |config| return nil if CONFIG.dig(config).blank? }
      "http://#{CONFIG.dig('proxy_user_prefix').gsub(/-country$/, "-session-#{Random.rand(100000)}")}:#{CONFIG.dig('proxy_pass')}@#{CONFIG.dig('proxy_host')}:#{CONFIG.dig('proxy_port')}"
    end

    def store_video_folder(url, local_path, public_path, key_id)
      Pender::Store.upload_video_folder(local_path)
      id = File.basename(local_path)
      public_path = File.join(public_path, id)
      data = organize_video_files(public_path, local_path)
      FileUtils.rm_rf(local_path)
      Media.notify_webhook_and_update_cache('video_archiver', url, data, key_id)
    end

    def organize_video_files(public_path, local_path)
      data = { info: nil, videos: [], subtitles: [], thumbnails: [] }
      Dir.glob("#{local_path}/*").each do |filename|
        filepath = "#{public_path}/#{File.basename(filename)}"
        mime_type = Rack::Mime.mime_type(File.extname(filename))
        case mime_type
        when /^image/
          data[:thumbnails] << filepath
        when /^video/
          data[:videos] << filepath
          data[:location] ||= filepath
        when /application\/json/
          data[:info] ||= filepath
        else
          data[:subtitles] << filepath
        end
      end
      data
    end
  end
end
