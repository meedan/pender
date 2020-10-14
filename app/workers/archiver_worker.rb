class ArchiverWorker
  include Sidekiq::Worker

  sidekiq_retries_exhausted { |msg, e| retries_exhausted_callback(msg, e) }

  def self.retries_exhausted_callback(msg, _e)
    args = msg['args']
    Media.give_up(args[0], args[1], args[2], msg.with_indifferent_access)
  end

  def perform(url, archiver, key_id, supported = nil)
    key = ApiKey.where(id: key_id).first
    Media.send("send_to_#{archiver}", url, key_id, supported)
  end
end

