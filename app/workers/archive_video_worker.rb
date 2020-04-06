require 'timeout'
require 'pender_store'

class ArchiveVideoWorker
  include Sidekiq::Worker

  def perform(url, local_path, public_path, key_id)
    begin
      Pender::Store.upload_video_folder(local_path)
      id = File.basename(local_path)
      public_path = File.join(public_path, id)
      data = video_files(public_path, local_path)
      FileUtils.rm_rf(local_path)
    rescue StandardError => e
      message = '[Video Archiver] Could not upload video data'
      Airbrake.notify(e, url: url, archiver: 'video_archiver', error_code: 5, error_message: e.message) if Airbrake.configured?
      Rails.logger.warn level: 'WARN', messsage: message, url: url, archiver: 'video_archiver', error_class: e.class, error_message: e.message
      data = { error: { message: I18n.t(:could_not_archive, error_message: message), code: 5 }}
    end
    Media.notify_webhook_and_update_cache('video_archiver', url, data, key_id)
  end

  def video_files(public_path, local_path)
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
