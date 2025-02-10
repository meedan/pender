module MediaArchiveOrgArchiver
  extend ActiveSupport::Concern

  included do
    Media.declare_archiver('archive_org', [/^.*$/], :only)
  end

  def archive_to_archive_org(url, key_id)
    ArchiverWorker.perform_in(30.seconds, url, 'archive_org', key_id)
  end

  module ClassMethods
    def send_to_archive_org(url, key_id, _supported = nil)
      handle_archiving_exceptions('archive_org', { url: url, key_id: key_id }) do
        encoded_uri = RequestHelper.encode_url(url)
        snapshot_data = Media.get_available_archive_org_snapshot(encoded_uri, key_id)
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
          ArchiverStatusJob.perform_in(2.minutes, body['job_id'], url, key_id)
        else
          data = snapshot_data.to_h.merge({ error: { message: "(#{body['status_ext']}) #{body['message']}", code: Lapis::ErrorCodes::const_get('ARCHIVER_ERROR') }})
          Media.notify_webhook_and_update_cache('archive_org', url, data, key_id)

          if body['message']&.include?('The same snapshot') || body['status_ext'] == 'error:too-many-daily-captures'
            PenderSentry.notify(
              Pender::Exception::TooManyCaptures.new(body["message"]),
              url: url,
              response_body: body
            )
          elsif body['status_ext'] == 'error:blocked-url'
            PenderSentry.notify(
              Pender::Exception::BlockedUrl.new(body["message"]),
              url: url,
              response_body: body
            )
          else
            raise Pender::Exception::ArchiveOrgError, "(#{body['status_ext']}) #{body['message']}"
          end
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
        data
      else
        nil
      end
    end

    def get_archive_org_status(job_id, url, key_id)
      begin
        http, request = Media.archive_org_request("https://web.archive.org/save/status/#{job_id}", 'Get')
        response = http.request(request)
        body = JSON.parse(response.body)
        if body['status'] == 'success'
         location = "https://web.archive.org/web/#{body['timestamp']}/#{url}"
          data = { location: location }
          Media.notify_webhook_and_update_cache('archive_org', url, data, key_id)
        else
          message = body['status'] == 'pending' ? 'Capture is pending' : "(#{body['status_ext']}) #{body['message']}"
          raise Pender::Exception::RetryLater, message
        end
      rescue StandardError => error
        raise Pender::Exception::RetryLater, error.message
      end
    end

    def archive_org_request(request_url, verb)
      uri = RequestHelper.parse_url(request_url)
      http = Net::HTTP.new(uri.host, uri.inferred_port)
      http.use_ssl = uri.scheme == "https"
      headers = {
        'Accept' => 'application/json',
        'Authorization' => "LOW #{PenderConfig.get('archive_org_access_key')}:#{PenderConfig.get('archive_org_secret_key')}",
        'X-Priority-Reduced' => '1'
      }
      [http, "Net::HTTP::#{verb}".constantize.new(uri, headers)]
    end
  end
end
