require 'error_codes'

module Api
  module V1
    class BaseApiController < ApplicationController

      before_filter :remove_empty_params_and_headers
      before_filter :set_custom_response_headers
      before_filter :authenticate_from_token!

      respond_to :json

      def about
        return unless request.format.json?
        archivers = Media.enabled_archivers(Media::ARCHIVERS.keys)
        info = {
          name: "Keep",
          version: VERSION,
          archivers: archivers.map {|a| {key: a[0], label: a[0].tr('_', '.').capitalize }}
        }
        render_success 'about', info
      end

      private

      def authenticate_from_token!
        header = PenderConfig.get('authorization_header') || 'X-Token'
        token = request.headers[header]
        ApiKey.current = ApiKey.where(access_token: token).where('expire_at > ?', Time.now).last
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
                         code: LapisConstants::ErrorCodes::const_get(code)
                       }
                     },
                     status: status
      end

      def render_unauthorized
        render_error I18n.t(:unauthorized), 'UNAUTHORIZED', 401
      end

      def render_parameters_missing
        render_error I18n.t(:parameters_missing), 'MISSING_PARAMETERS'
      end

      def render_url_invalid
        render_error I18n.t(:url_not_valid), 'INVALID_VALUE'
      end
    end
  end
end
