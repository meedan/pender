module MediaVideoVaultArchiver
  extend ActiveSupport::Concern

  # We should restrict to only the services that Video Vault supports, but we don't know which they are
  included do
    Media.declare_archiver('video_vault', [/^.*$/], :only)
  end

  def archive_to_video_vault
    token = CONFIG['video_vault_token']
    return if token.blank?
    url = self.url
    key_id = self.key ? self.key.id : nil
    self.class.send_to_video_vault_in_background(url, key_id, token)
  end

  module ClassMethods
    def send_to_video_vault_in_background(url, key_id, token)
      self.delay_for(1.second).send_to_video_vault(url, key_id, token)
    end

    def send_to_video_vault(url, key_id, token, attempts = 0, package = nil, endpoint = '')
      return if attempts > 5

      key = ApiKey.where(id: key_id).last
      settings = key ? key.application_settings.with_indifferent_access : {}
      uri = URI("https://www.bravenewtech.org/api/#{endpoint}")

      params = { token: token }
      params[:url] = url if package.blank?
      params[:package] = package unless package.blank?
      response = Net::HTTP.post_form(uri, params)

      data = JSON.parse(response.body)
      data['timestamp'] = Time.now.to_i

      # If not finished (error or success), run again
      if !data.has_key?('location') && data['status'].to_i != 418 && data.has_key?('package')
        Media.delay_for(3.minutes).send_to_video_vault(url, key_id, token, attempts + 1, data['package'], 'status.php')
      else
        Media.notify_webhook('video_vault', url, data, settings)
        Media.update_cache(url, { archives: { video_vault: data } })
      end
    end
  end
end
