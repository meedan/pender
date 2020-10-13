class ArchiverWorker
  include Sidekiq::Worker

  sidekiq_retries_exhausted do |error_info, exception|
    args = error_info['args']
    error = { error_class: error_info['error_class'], error_message: error_info['error_message'] }.with_indifferent_access
    Media.give_up(args[0], args[1], args[2], error)
  end

  def perform(url, archiver, key_id, supported = nil)
    key = ApiKey.where(id: key_id).first
    Media.send("send_to_#{archiver}", url, key_id, supported)
  end
end

