require 'error_codes'

module Api
  module V1
    class BaseApiController < ApplicationController
      include BaseDoc

      before_filter :remove_empty_params_and_headers
      before_filter :set_custom_response_headers
      before_filter :authenticate_from_token!

      respond_to :json

      def about
        archivers = Media.enabled_archivers(*Media::ARCHIVERS.keys)
        info = {
          name: "Keep",
          archivers: archivers.map {|a| {key: a[0], label: a[0].gsub('_', '.').capitalize }}
        }
        render_success 'about', info
      end

      private

      def authenticate_from_token!
        header = CONFIG['authorization_header'] || 'X-Token'
        token = request.headers[header]
        @key = ApiKey.where(access_token: token).where('expire_at > ?', Time.now).last
        (render_unauthorized and return false) if @key.nil?
      end

      def get_params
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

      # def render_unknown_error
      #   render_error 'Unknown error', 'UNKNOWN'
      # end

      # def render_invalid
      #   render_error 'Invalid value', 'INVALID_VALUE'
      # end

      def render_parameters_missing
        render_error I18n.t(:parameters_missing), 'MISSING_PARAMETERS'
      end

      # def render_not_found
      #   render_error 'Id not found', 'ID_NOT_FOUND', 404
      # end

      # def render_not_implemented
      #   render json: { success: true, message: 'NOT_IMPLEMENTED' }, status: 200
      # end

      # def render_deleted
      #   render_error 'This object was deleted', 'ID_NOT_FOUND', 410
      # end

      def render_url_invalid
        render_error I18n.t(:url_not_valid), 'INVALID_VALUE'
      end
    end
  end
end
