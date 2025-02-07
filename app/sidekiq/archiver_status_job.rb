# Notes on the rationale for retrying
# 1. I used sidekiqs own retrying/backing off formula as a starting point
#  https://github.com/sidekiq/sidekiq/wiki/Error-Handling#automatic-job-retry
# 2. start retrying:
  # I think ramping up to 4.5 and starting and always adding 5 minutes might be enough.
  # It starts later and increases the intervals faster# 3. interval:
# 4. for how long:
  # 24 hours.
  # If we haven’t been able to get the status after 24 hours should it seems wasteful to keep trying

class ArchiverStatusJob
  include Sidekiq::Job
  sidekiq_options retry_for: 24.hours, queue: 'archiving'

  sidekiq_retry_in do |count|
    (count ** 4.5) + 300 + (rand(10) * (count + 1))
  end

  def perform(job_id, url, key_id)
    Media.get_archive_org_status(job_id, url, key_id)
  end
end
