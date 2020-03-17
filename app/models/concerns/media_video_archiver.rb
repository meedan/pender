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
      self.delay_for(15.seconds).archive_video(url, key_id)
    end

    def archive_video(url, key_id, supported = nil, attempts = 1, response = nil)
      Media.give_up('video_archiver', url, key_id, attempts, response) and return

      begin
        supported = supported_video?(url) if supported.nil?
        return if supported.is_a?(FalseClass) || notify_video_already_archived(url, key_id)
        id = Media.get_id(url)
        local_folder = File.join(Rails.root, 'tmp', 'videos', id)
        Media.give_up('video_archiver', url, key_id, attempts, response) and return
        response = system("youtube-dl", url, "-o#{local_folder}/#{id}.%(ext)s", "--restrict-filenames", "--no-warnings", "-q", "--write-all-thumbnails", "--write-info-json", "--all-subs", "-fogg/mp4/webm",  out: '/dev/null')

        if response
          ArchiveVideoWorker.perform_async(url, local_folder, self.archiving_folder, key_id)
        else
          Media.delay_for(3.minutes).archive_video(url, key_id, supported, attempts + 1, {message: '[Youtube-DL] Cannot download video data', code: 5})
        end
      rescue StandardError => e
        Media.delay_for(1.hour).archive_video(url, key_id, attempts + 1, {code: 5, message: e.message})
        Rails.logger.info "[Youtube-DL] Could not archive: #{e.message}"
        data = { error: { message: I18n.t(:could_not_archive, error_message: e.message), code: 5 }}
        Media.notify_webhook_and_update_cache('video_archiver', url, data, key_id)
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
      system("youtube-dl", url, "--restrict-filenames", "--no-warnings", "-g", "-q", out: '/dev/null')
    end
  end
end
