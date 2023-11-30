class ArchiverStatusJob
  include Sidekiq::Job

  def perform(job_id, url, key_id)
    Media.get_archive_org_status(job_id, url, key_id)
  end
end
