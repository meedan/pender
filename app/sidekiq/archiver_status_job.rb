# Notes on the rationale for retrying
# 1. I used sidekiqs own retrying/backing off formula as a starting point
#  https://github.com/sidekiq/sidekiq/wiki/Error-Handling#automatic-job-retry
# 2. start retrying:
  # aprox. after a minute, that should be more than enough (it usually doesn't take that long)
# 3. interval:
  # just add a bit of more time, instead of 15, 60.
  # It’s a small change but helps us start a bit later, a makes the intervals a bit longer.
  # I think this is enough to help, as this happens when we are waiting for the request to be processed by archive_org
# 4. for how long:
  # 24 hours.
  # If we haven’t been able to get the status after 24 hours should it seems wasteful to keep trying

class ArchiverStatusJob
  include Sidekiq::Job
  sidekiq_options retry_for: 24.hours, queue: 'archiving'

  sidekiq_retry_in do |count|
    (count ** 4) + 60 + (rand(10) * (count + 1))
  end

  def perform(job_id, url, key_id)
    Media.get_archive_org_status(job_id, url, key_id)
  end
end
