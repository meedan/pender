module MediaArchiveIsArchiver
  extend ActiveSupport::Concern

  included do
    Media.declare_archiver('archive_is', [/^.*$/], :only)
  end

  def archive_to_archive_is
    key_id = self.key ? self.key.id : nil
    self.class.send_to_archive_is_in_background(self.url, key_id)
  end

  module ClassMethods
    def send_to_archive_is_in_background(url, key_id)
      self.delay_for(1.second).send_to_archive_is(url, key_id)
    end

    def send_to_archive_is(url, key_id, attempts = 1)
      return if attempts > 20

      key = ApiKey.where(id: key_id).last
      settings = key ? key.application_settings.with_indifferent_access : {}

      uri = URI.parse('http://archive.is/submit/')
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri.request_uri)
      request.set_form_data({ url: url })
      response = http.request(request)

      if response['refresh']
        Media.delay_for(3.minutes).send_to_archive_is(url, key_id, attempts + 1)
      elsif response['location']
        data = { location: response['location'] }
        Media.notify_webhook('archive_is', url, data, settings)
        Media.update_cache(url, { archives: { archive_is: data } })
      else
        raise "Unexpected response from archive.is with code #{response.code}: #{response.body}"
      end
    end
  end
end
