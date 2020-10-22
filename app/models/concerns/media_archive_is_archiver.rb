module MediaArchiveIsArchiver
  extend ActiveSupport::Concern

  included do
    Media.declare_archiver('archive_is', [/^.*$/], :only)
  end

  def archive_to_archive_is
    self.class.send_to_archive_is_in_background(self.original_url, ApiKey.current&.id)
  end

  module ClassMethods
    def send_to_archive_is_in_background(url, key_id)
      ArchiverWorker.perform_async(url, :archive_is, key_id)
    end

    def send_to_archive_is(url, key_id, _supported = nil)
      handle_archiving_exceptions('archive_is', { url: url, key_id: key_id }) do
        uri = URI.parse('http://archive.today/submit/')
        http = Net::HTTP.new(uri.host, uri.port)
        request = Net::HTTP::Post.new(uri.request_uri)
        request.set_form_data({ url: url })
        response = http.request(request)
        Rails.logger.info level: 'INFO', message: '[archive_is] Sent URL to archive', url: url, code: response.code, response: response.message

        if response['location']
          data = { location: response['location'] }
          Media.notify_webhook_and_update_cache('archive_is', url, data, key_id)
        else
          raise Pender::RetryLater, "(#{response.code}) #{response.message}"
        end
      end
    end
  end
end
