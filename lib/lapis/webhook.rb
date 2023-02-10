module Lapis
  class Webhook
    def initialize(url, payload)
      @url = url
      @payload = payload
    end

    def notification_signature(payload)
      'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), PenderConfig.get('secret_token'), payload)
    end

    def notify
      payload = @payload.to_json
      uri = RequestHelper.parse_url(@url)
      http = Net::HTTP.new(uri.host, uri.inferred_port)
      http.use_ssl = uri.scheme == 'https'
      request = Net::HTTP::Post.new(uri.path)
      request.body = payload
      request['X-Signature'] = notification_signature(payload)
      request['Content-Type'] = 'application/json'
      http.request(request)
    end
  end
end
