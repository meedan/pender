require 'pender_store'

module MediaVideoArchiver
  extend ActiveSupport::Concern

  included do
    Media.declare_archiver('video', [/^.*$/], :only)
  end

  def archive_to_video
    self.class.archive_video_in_background(self.url, ApiKey.current&.id)
  end

  module ClassMethods
    def archive_video_in_background(url, key_id)
      self.delay(queue: 'video_archiving').send_to_video_archiver(url, key_id)
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
        system('youtube-dl', uri, proxy, output, '--restrict-filenames', '--no-warnings', '-q', '--write-all-thumbnails', '--write-info-json', '--all-subs', '-fogg/mp4/webm')

        if $?.success?
          Media.store_video_folder(url, local_folder, self.archiving_folder, key_id)
        else
          retry_archiving_after_failure('ARCHIVER_FAILURE', 'video_archiver', 5.minutes, { url: url, key_id: key_id, attempts: attempts, code: $?.exitstatus, message: I18n.t(:archiver_video_not_downloaded), supported: supported })
        end
      end
    end

    def archiving_folder
      storage = PenderConfig.get('storage')
      storage.dig('video_asset_path') || "#{storage.dig('endpoint')}/#{Pender::Store.current.video_bucket_name}/video"
    end

    def notify_video_already_archived(url, key_id)
      id = Media.get_id(url)
      data = Pender::Store.current.read(id, :json)
      return if data.nil? || data.dig(:archives, :video_archiver, :location).nil?
      settings = Media.api_key_settings(key_id)
      Media.notify_webhook('video_archiver', url, data, settings)
    end

    def supported_video?(url, key_id = nil)
      uri = URI.encode url
      system('youtube-dl', uri, "--proxy=#{Media.yt_download_proxy(uri)}", '--restrict-filenames', '--no-warnings', '-g', '-q')
      unless $?.success?
        data = { error: { message: I18n.t(:archiver_not_supported_media, code: $?.exitstatus), code: LapisConstants::ErrorCodes::const_get('ARCHIVER_NOT_SUPPORTED_MEDIA') }}
        Media.notify_webhook_and_update_cache('video_archiver', url, data, key_id)
      end
      $?.success?
    end

    def yt_download_proxy(url)
      uri = URI.parse(url)
      return unless uri.host.match(/youtube\.com/)
      proxy = Media.valid_proxy('ytdl_proxy')
      return nil unless proxy
      "http://#{proxy.dig('user_prefix')}:#{proxy.dig('pass')}@#{proxy.dig('host')}:#{proxy.dig('port')}"
    end

    def store_video_folder(url, local_path, public_path, key_id)
      Pender::Store.current.upload_video_folder(local_path)
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
