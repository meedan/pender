# Notes on the rationale for retrying
# 1. I used sidekiqs own retrying/backing off formula as a starting point
#  https://github.com/sidekiq/sidekiq/wiki/Error-Handling#automatic-job-retry
# 2. start retrying:
  # after 5 minutes, because of archive.org: https://archive.org/details/toomanyrequests_20191110
# 3. interval:
  # I think ramping up to 4.5 and starting and always adding 5 minutes might be enough.
  # It starts later and increases the intervals faster
# 4. for how long:
  # 24 hours.
  # After that I think it becomes increasingly possible that the url is no longer the version the user might have wanted to store
# 5. this schedule is for both archive.org and perma.cc
  # because we are unable to specify by the exception (it's always RetryLater)
  # We prioritized archive org schedule because:
  #  - it’s the one we use the most
  #  - it’s the one with the most problems

class ArchiverWorker
  include Sidekiq::Worker
  sidekiq_options retry_for: 24.hours, queue: 'archiving'

  sidekiq_retries_exhausted { |msg, e| retries_exhausted_callback(msg, e) }

  sidekiq_retry_in do |count|
    (count ** 4.5) + 300 + (rand(10) * (count + 1))
  end

  def self.retries_exhausted_callback(msg, _e)
    Media.give_up(msg.with_indifferent_access)
  end

  def perform(url, archiver, key_id, supported = nil)
    Media.send("send_to_#{archiver}", url, key_id, supported)
  end
end
