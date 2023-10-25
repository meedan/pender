module MediaPermaCcArchiver
  extend ActiveSupport::Concern

  included do
    Media.declare_archiver('perma_cc', [/^.*$/], :only)
  end

  def archive_to_perma_cc(url, key_id)
    ArchiverWorker.perform_in(30.seconds, url, :perma_cc, key_id)
  end

  module ClassMethods
    def send_to_perma_cc(url, key_id, _supported = nil)
      handle_archiving_exceptions('perma_cc', { url: url, key_id: key_id }) do
        perma_cc_key = PenderConfig.get('perma_cc_key')
        return if skip_perma_cc_archiver(perma_cc_key, url, key_id)

        encoded_uri = RequestHelper.encode_url(url)
        uri = RequestHelper.parse_url("https://api.perma.cc/v1/archives/?api_key=#{perma_cc_key}")
        headers = { 'Content-Type': 'application/json' }
        http = Net::HTTP.new(uri.host, uri.inferred_port)
        http.use_ssl = true
        request = Net::HTTP::Post.new(uri.request_uri, headers)
        request.body = { url: encoded_uri }.to_json
        response = http.request(request)
        Rails.logger.info level: 'INFO', message: '[perma_cc] Sent URL to archive', url: url, code: response.code, response: response.message

        if !response.nil? && [200,201].include?(response.code.to_i) && !response.body.blank?
          body = JSON.parse(response.body)
          data = { location: 'http://perma.cc/' + body['guid'] }
          Media.notify_webhook_and_update_cache('perma_cc', url, data, key_id)
        else
          raise Pender::Exception::PermaCcError, "(#{response.code}) #{response.message}"
        end
      end
    end

    def skip_perma_cc_archiver(perma_cc_key, url, key_id)
      if perma_cc_key.nil?
        data = { error: { message: 'Missing authentication key', code: Lapis::ErrorCodes::const_get('ARCHIVER_MISSING_KEY') }}
        Media.notify_webhook_and_update_cache('perma_cc', url, data, key_id)
      else
        return false
      end
    end
  end
end
