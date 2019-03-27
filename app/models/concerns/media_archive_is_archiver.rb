module MediaArchiveIsArchiver
  extend ActiveSupport::Concern

  included do
    Media.declare_archiver('archive_is', [/^.*$/], :only, false)
  end

  def archive_to_archive_is
    key_id = self.key ? self.key.id : nil
    self.class.send_to_archive_is_in_background(self.url, key_id)
  end

  module ClassMethods
    def send_to_archive_is_in_background(url, key_id)
      self.delay_for(15.seconds).send_to_archive_is(url, key_id)
    end

    def send_to_archive_is(url, key_id, attempts = 1, response = nil)
      Media.give_up('archive_is', url, key_id, attempts, response) and return

      uri = URI.parse('http://archive.is/submit/')
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri.request_uri)
      request.set_form_data({ url: url })
      response = http.request(request)
      Rails.logger.info "[Archiver Archive.is] Sending #{url} to Archive.is: Code: #{response.code} Response: #{response.body}"

      if response['refresh']
        Media.delay_for(3.minutes).send_to_archive_is(url, key_id, attempts + 1, {code: response.code, message: response.message})
      elsif response['location']
        data = { location: response['location'] }
        Media.notify_webhook_and_update_cache('archive_is', url, data, key_id)
      else
        Airbrake.notify(StandardError.new('Unexpected response from archive.is'), parameters: {url: url, archiver: 'archive.is', error_code: response.code, error_message: response.message, error_body: response.body}) if Airbrake.configuration.api_key && !response.nil?
        data = { error: { message: I18n.t(:could_not_archive, error_message: response.message), code: response.code }}
        Media.notify_webhook_and_update_cache('archive_is', url, data, key_id)
      end
    end
  end
end
