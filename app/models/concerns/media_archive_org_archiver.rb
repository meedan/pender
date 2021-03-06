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
        return if Media.get_available_archive_org_snapshot(encoded_uri, key_id)
        http, request = Media.archive_org_request('https://web.archive.org/save', 'Post')
        request.set_form_data(
          "capture_screenshot" => "1",
          "skip_first_archive" => "1",
          "if_not_archived_within" => "24h",
          "url" => encoded_uri,
        )
        response = http.request(request)
        Rails.logger.info level: 'INFO', message: '[archive_org] Sent URL to archive', url: url, code: response.code, response: response.message
        body = JSON.parse(response.body)
        if body['job_id']
          Media.delay.get_archive_org_status(body['job_id'], url, key_id)
        else
          PenderAirbrake.notify(StandardError.new(body['message']), url: url, response_body: body)
          data = { error: { message: "(#{body['status_ext']}) #{body['message']}", code: LapisConstants::ErrorCodes::const_get('ARCHIVER_ERROR') }}
          Media.notify_webhook_and_update_cache('archive_org', url, data, key_id)
        end
      end
    end

    def get_available_archive_org_snapshot(url, key_id)
      timestamp = Time.now.strftime('%Y%m%d')
      http, request = Media.archive_org_request("http://archive.org/wayback/available?url=#{url}&timestamp=#{timestamp}", 'Get')
      response = http.request(request)
      body = JSON.parse(response.body)
      if body.dig('archived_snapshots', 'closest', 'available')
        location = body.dig('archived_snapshots', 'closest', 'url')
        data = { location: location }
        Media.notify_webhook_and_update_cache('archive_org', url, data, key_id)
        return true
      end
      nil
    end

    def get_archive_org_status(job_id, url, key_id)
      http, request = Media.archive_org_request("https://web.archive.org/save/status/#{job_id}", 'Get')
      response = http.request(request)
      body = JSON.parse(response.body)
      if body['status'] == 'success'
        location = "https://web.archive.org/web/#{body['timestamp']}/#{url}"
        data = { location: location }
        Media.notify_webhook_and_update_cache('archive_org', url, data, key_id)
      else
        message = body['status'] == 'pending' ? 'Capture is pending' : "(#{body['status_ext']}) #{body['message']}"
        raise Pender::RetryLater, message
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
