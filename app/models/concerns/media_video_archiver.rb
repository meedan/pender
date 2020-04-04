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
      handle_archiving_exceptions('video_archiver', 1.hour, url, key_id, attempts, supported) do
        supported = supported_video?(url) if supported.nil?
        return if supported.is_a?(FalseClass) || notify_video_already_archived(url, key_id)
        id = Media.get_id(url)
        local_folder = File.join(Rails.root, 'tmp', 'videos', id)
        Media.give_up('video_archiver', url, key_id, attempts, response) and return
        response = system("youtube-dl", URI.encode(url), "--proxy=#{Media.yt_download_proxy(URI.encode(url))}", "-o#{local_folder}/#{id}.%(ext)s", "--restrict-filenames", "--no-warnings", "-q", "--write-all-thumbnails", "--write-info-json", "--all-subs", "-fogg/mp4/webm",  out: '/dev/null')
        if response
          ArchiveVideoWorker.perform_async(url, local_folder, self.archiving_folder, key_id)
        else
          Media.delay_for(5.minutes).send_to_video_archiver(url, key_id, attempts + 1, {message: '[Youtube-DL] Cannot download video data', code: 5}, supported)
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

    def supported_video?(url)
      url = URI.encode url
      system("youtube-dl", URI.encode(url), "--proxy=#{Media.yt_download_proxy(url)}", "--restrict-filenames", "--no-warnings", "-g", "-q", out: '/dev/null')
    end

    def yt_download_proxy(url)
      uri = URI.parse(url)
      return unless uri.host.match(/youtube\.com/)
      ['proxy_host', 'proxy_port', 'proxy_pass', 'proxy_user_prefix'].each { |config| return nil if CONFIG.dig(config).blank? }
      "http://#{CONFIG.dig('proxy_user_prefix').gsub(/-country$/, "-session-#{Random.rand(100000)}")}:#{CONFIG.dig('proxy_pass')}@#{CONFIG.dig('proxy_host')}:#{CONFIG.dig('proxy_port')}"
    end
  end
end
