class ArchiverWorker
  include Sidekiq::Worker
  sidekiq_options retry_for: 24.hours

  sidekiq_retries_exhausted { |msg, e| retries_exhausted_callback(msg, e) }

  sidekiq_retry_in do |count, exception, jobhash|
    return unless exception.is_a? Pender::Exception::ArchiveOrgError
    (count ** 4.5) + 300 + (rand(10) * (count + 1))
  end

  def self.retries_exhausted_callback(msg, _e)
    Media.give_up(msg.with_indifferent_access)
  end

  def perform(url, archiver, key_id, supported = nil)
    Media.send("send_to_#{archiver}", url, key_id, supported)
  end
end
