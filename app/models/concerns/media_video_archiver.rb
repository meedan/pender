require 'pender/store'

module MediaVideoArchiver
  extend ActiveSupport::Concern

  included do
    Media.declare_archiver('video', [/^.*$/], :only)
  end

  def archive_to_video(url, key_id)
    ArchiverWorker.perform_async(url, :video_archiver, key_id)
  end

  module ClassMethods
    def send_to_video_archiver(url, key_id, supported = nil)
      handle_archiving_exceptions('video_archiver', { url: url, key_id: key_id }) do
        supported = supported_video?(url, key_id) if supported.nil?
        return if supported.is_a?(FalseClass) || notify_video_already_archived(url, key_id)
        id = Media.get_id(url)
        local_folder = File.join(Rails.root, 'tmp', 'videos', id)
        uri = RequestHelper.encode_url(url)
        proxy = "--proxy=#{Media.yt_download_proxy(uri)}"
        output = "-o#{local_folder}/#{id}.%(ext)s"
        system('youtube-dl', uri, proxy, output, '--restrict-filenames', '--no-warnings', '-q', '--write-all-thumbnails', '--write-info-json', '--all-subs', '-fogg/mp4/webm')

        if $?.success?
          Media.store_video_folder(url, local_folder, self.archiving_folder, key_id)
        else
          raise Pender::Exception::RetryLater, "(#{$?.exitstatus}) Requested video not available for download"
        end
      end
    end

    def archiving_folder
      Pender::Store.current.storage_path('video')
    end

    def notify_video_already_archived(url, key_id)
      id = Media.get_id(url)
      data = Pender::Store.current.read(id, :json)
      return if data.nil? || data.dig(:archives, :video_archiver, :location).nil?
      settings = Media.api_key_settings(key_id)
      Media.notify_webhook('video_archiver', url, data, settings)
    end

    def supported_video?(url, key_id = nil)
      uri = RequestHelper.encode_url(url)
      system('youtube-dl', uri, "--proxy=#{Media.yt_download_proxy(uri)}", '--restrict-filenames', '--no-warnings', '-g', '-q')
      unless $?.success?
        data = { error: { message: "#{$?.exitstatus} Unsupported URL", code: Lapis::ErrorCodes::const_get('ARCHIVER_NOT_SUPPORTED_MEDIA') }}
        Media.notify_webhook_and_update_cache('video_archiver', url, data, key_id)
      end
      $?.success?
    end

    def yt_download_proxy(url)
      uri = RequestHelper.parse_url(url)
      return unless uri.host.match(/youtube\.com/)
      proxy = RequestHelper.valid_proxy('ytdl_proxy')
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
