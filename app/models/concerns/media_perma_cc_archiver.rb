module MediaPermaCcArchiver
  extend ActiveSupport::Concern

  included do
    Media.declare_archiver('perma_cc', [/^.*$/], :only)
  end

  def archive_to_perma_cc
    self.class.send_to_perma_cc_in_background(self.original_url, ApiKey.current&.id)
  end

  module ClassMethods
    def send_to_perma_cc_in_background(url, key_id)
      self.delay_for(15.seconds).send_to_perma_cc(url, key_id)
    end

    def send_to_perma_cc(url, key_id, attempts = 1, response = nil, _supported = nil)
      perma_cc_key = PenderConfig.get('perma_cc_key')
      return if skip_perma_cc_archiver(perma_cc_key, url, key_id)
      Media.give_up('perma_cc', url, key_id, attempts, response) and return

      handle_archiving_exceptions('perma_cc', 24.hours, { url: url, key_id: key_id, attempts: attempts }) do
        encoded_uri = URI.encode(URI.decode(url))
        uri = URI.parse("https://api.perma.cc/v1/archives/?api_key=#{perma_cc_key}")
        headers = { 'Content-Type': 'application/json' }
        http = Net::HTTP.new(uri.host, uri.port)
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
          retry_archiving_after_failure('ARCHIVER_FAILURE', 'perma_cc', 3.minutes, { url: url, key_id: key_id, attempts: attempts, code: response.code, message: response.message })
        end
      end
    end

    def skip_perma_cc_archiver(perma_cc_key, url, key_id)
      if perma_cc_key.nil?
        data = { error: { message: I18n.t(:archiver_missing_key), code: LapisConstants::ErrorCodes::const_get('ARCHIVER_MISSING_KEY') }}
        Media.notify_webhook_and_update_cache('perma_cc', url, data, key_id)
      else
        id = Media.get_id(url)
        data = Pender::Store.current.read(id, :json)
        return if data.nil? || data.dig(:archives, :perma_cc).nil?
        settings = Media.api_key_settings(key_id)
        Media.notify_webhook('perma_cc', url, data, settings)
      end
      return true
    end

  end
end
