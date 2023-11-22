class ArchiverStatusWorker
  include Sidekiq::Worker

  def perform(url, job_id, key_id, supported = nil)
    Media.get_archive_org_status(job_id, url, key_id)
  end
end