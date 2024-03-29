require 'lapis/error_codes'

module Api
  module V1
    class BaseApiController < ApplicationController

      before_action :remove_empty_params_and_headers
      before_action :set_custom_response_headers
      before_action :authenticate_from_token!
      after_action :unload_current_config

      respond_to :json

      def about
        return unless request.format.json?
        info = {
          name: "Keep",
          version: VERSION,
          archivers: Media::ENABLED_ARCHIVERS
        }
        render_success 'about', info
      end

      private

      def unload_current_config
        ApiKey.current = nil
        PenderConfig.current = nil
        Pender::Store.current = nil
      end

      def authenticate_from_token!
        header = PenderConfig.get('authorization_header') || 'X-Token'
        token = request.headers[header]

        api_key = ApiKey.valid.where(access_token: token).last
        ApiKey.current = api_key
        TracingService.add_attributes_to_current_span('app.api_key' => api_key&.id)
        PenderSentry.set_user_info(api_key: api_key&.id)

        PenderConfig.reload
        (render_unauthorized and return false) if ApiKey.current.nil?
      end

      def get_params
        @refresh = params[:refresh] == '1'
        @archivers = params[:archivers]
        params.reject{ |k, _v| ['id', 'action', 'controller', 'format'].include?(k) }
      end

      def remove_empty_params_and_headers
        params.reject!{ |_k, v| v.blank? }
        request.headers.each{ |k, v| request.headers[k] = nil if (k =~ /HTTP_/).present? && v.blank? }
      end

      def set_custom_response_headers
        response.headers['X-Build'] = BUILD
        response.headers['Accept'] ||= ApiConstraints.accept(1)
      end

      # Renderization methods

      def render_success(type = 'success', object = nil)
        json = { type: type }
        json[:data] = object unless object.nil?
        render json: json, status: 200
      end

      def render_error(message, code, status = 400)
        render json: { type: 'error',
                       data: {
                         message: message,
                         code: Lapis::ErrorCodes::const_get(code)
                       }
                     },
                     status: status
      end

      def render_unauthorized
        render_error 'Unauthorized', 'UNAUTHORIZED', 401
      end

      def render_parameters_missing
        render_error 'Parameters missing', 'MISSING_PARAMETERS'
      end

      def render_url_invalid
        render_error 'The URL is not valid', 'INVALID_VALUE'
      end
    end
  end
end
