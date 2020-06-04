class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  skip_before_filter :verify_authenticity_token

  def append_info_to_payload(payload)
    super
    case
      when payload[:status].to_i < 300
        payload[:level] = 'INFO'
      when payload[:status].to_i < 400
        payload[:level] = 'WARN'
      else
        payload[:level] = 'ERROR'
    end
  end

end
