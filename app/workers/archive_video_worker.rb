require 'timeout'
require 'pender_store'

class ArchiveVideoWorker
  include Sidekiq::Worker

  def perform(url, local_path, public_path, key_id)
    begin
      Pender::Store.upload_video_folder(local_path)
      id = File.basename(local_path)
      public_path = File.join(public_path, id)
      video_path = Dir.glob("#{local_path}/*.{mp4,webm,ogg}").first
      data = { location: "#{public_path}/#{File.basename(video_path)}", path: public_path }
    rescue StandardError => e
      message = '[Youtube-DL] Could not upload video data'
      Airbrake.notify(StandardError.new(message, url: url, archiver: 'video_archiver', error_code: 5, error_message: e.message)) if Airbrake.configured?
      data = { error: { message: I18n.t(:could_not_archive, error_message: message), code: 5 }}
    end
    Media.notify_webhook_and_update_cache('video_archiver', url, data, key_id)
  end
end
