module MediaArchiveOrgArchiver
  extend ActiveSupport::Concern

  included do
    Media.declare_archiver('archive_org', [/^.*$/], :only)
  end

  def archive_to_archive_org
    key_id = self.key ? self.key.id : nil
    self.class.send_to_archive_org_in_background(self.url, key_id)
  end

  module ClassMethods
    def send_to_archive_org_in_background(url, key_id)
      self.delay_for(15.seconds).send_to_archive_org(url, key_id)
    end

    def send_to_archive_org(url, key_id, attempts = 1)
      Media.give_up('archive_org', url, key_id, attempts) and return

      encoded_uri = URI.encode(URI.decode(url))
      uri = URI.parse("https://web.archive.org/save/#{encoded_uri}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)
      Rails.logger.info "[Archiver Archive.org] Sending #{url} to Archive.org: Code: #{response.code}"

      if response['content-location']
        data = { location: 'https://web.archive.org' + response['content-location'] }
        Media.notify_webhook_and_update_cache('archive_org', url, data, key_id)
      else
        Media.delay_for(3.minutes).send_to_archive_org(url, key_id, attempts + 1)
      end
    end
  end
end
