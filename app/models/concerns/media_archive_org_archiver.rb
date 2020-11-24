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
      handle_archiving_exceptions('archive_org', { url: url, key_id: key_id }) do
        encoded_uri = URI.encode(URI.decode(url))
        http, request = Media.archive_org_request('https://web.archive.org/save', 'Post')
        request.set_form_data(
          "capture_screenshot" => "1",
          "skip_first_archive" => "1",
          "url" => encoded_uri,
        )
        response = http.request(request)
        Rails.logger.info level: 'INFO', message: '[archive_org] Sent URL to archive', url: url, code: response.code, response: response.message
        body = JSON.parse(response.body)
        if body['job_id']
          Media.get_archive_org_status(body, url, key_id)
        else
          PenderAirbrake.notify(StandardError.new(body['message']), url: url)
          data = { error: { message: "(#{body['status_ext']}) #{body['message']}", code: LapisConstants::ErrorCodes::const_get('ARCHIVER_ERROR') }}
          Media.notify_webhook_and_update_cache('archive_org', url, data, key_id)
        end
      end
    end

    def get_archive_org_status(body, url, key_id)
      http, request = Media.archive_org_request("https://web.archive.org/save/status/#{body['job_id']}", 'Get')
      response = http.request(request)
      body = JSON.parse(response.body)
      if body['status'] == 'success'
        location = "https://web.archive.org/web/#{body['timestamp']}/#{url}"
        data = { location: location }
        Media.notify_webhook_and_update_cache('archive_org', url, data, key_id)
      else
        raise Pender::RetryLater, "(#{body['status_ext']}) #{body['message']}"
      end
    end

    def archive_org_request(request_url, verb)
      uri = URI.parse(request_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      headers = {
        'Accept' => 'application/json',
        'Authorization' => "LOW #{PenderConfig.get('archive_org_access_key')}:#{PenderConfig.get('archive_org_secret_key')}"
      }
      [http, "Net::HTTP::#{verb}".constantize.new(uri, headers)]
    end
  end
end
