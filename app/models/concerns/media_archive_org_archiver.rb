module MediaArchiveOrgArchiver
  extend ActiveSupport::Concern

  included do
    Media.declare_archiver('archive_org', [/^.*$/], :only)
  end

  def archive_to_archive_org
    self.class.send_to_archive_org_in_background(self.original_url, ApiKey.current&.id)
  end

  module ClassMethods
    def send_to_archive_org_in_background(url, key_id)
      ArchiverWorker.perform_async(url, :archive_org, key_id)
    end

    def send_to_archive_org(url, key_id, _supported = nil)
      ApiKey.current = ApiKey.find_by(id: key_id)
      encoded_uri = URI.encode(URI.decode(url))
      uri = URI.parse("https://web.archive.org/save/#{encoded_uri}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)
      Rails.logger.info level: 'INFO', message: '[archive_org] Sent URL to archive', url: url, code: response.code, response: response.message
      location = response['content-location'] || response['location']

      if location
        address = 'https://web.archive.org'
        location = address + location unless location.starts_with?(address)
        data = { location: location }
        Media.notify_webhook_and_update_cache('archive_org', url, data, key_id)
      else
        retry_archiving_after_failure('archive_org', { url: url, key_id: key_id, code: response.code, message: response.message })
      end
    end
  end
end
