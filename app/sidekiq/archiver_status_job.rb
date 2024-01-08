class ArchiverStatusJob
  include Sidekiq::Job
  sidekiq_options retry_for: 24.hours

  sidekiq_retry_in do |count|
    (count ** 4) + 60 + (rand(10) * (count + 1))
  end

  def perform(job_id, url, key_id)
    Media.get_archive_org_status(job_id, url, key_id)
  end
end
