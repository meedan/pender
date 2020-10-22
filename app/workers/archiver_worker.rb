class ArchiverWorker
  include Sidekiq::Worker

  sidekiq_retries_exhausted { |msg, e| retries_exhausted_callback(msg, e) }

  def self.retries_exhausted_callback(msg, _e)
    Media.give_up(msg.with_indifferent_access)
  end

  def perform(url, archiver, key_id, supported = nil)
    Media.send("send_to_#{archiver}", url, key_id, supported)
  end
end

