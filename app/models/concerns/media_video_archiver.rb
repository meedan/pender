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

    def archive_video(url, key_id, attempts = 1, response = nil)
      return if !supported_video?(url) || notify_video_already_archived(url, key_id)
      local_folder = self.tmp_archiving_folder(url)
      Media.give_up('video_archiver', url, key_id, attempts, response) and return
      response = system("youtube-dl", "#{url} -q --write-all-thumbnails --write-info-json --all-subs -f 'ogg/mp4/webm' -o '#{local_folder}/%(id)s.%(ext)s'")

      if response
        ArchiveVideoWorker.perform_async(url, local_folder, self.archiving_folder, key_id)
      else
        Media.delay_for(3.minutes).archive_video(url, key_id, attempts + 1, {message: '[Youtube-DL] Cannot download video data', code: 5})
      end
    end

    def tmp_archiving_folder(url)
      File.join(Rails.root, 'tmp', 'videos', Media.get_id(url))
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
      system("youtube-dl", "#{url} -g -q")
    end
  end
end
