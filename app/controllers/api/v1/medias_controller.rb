module Api
  module V1
    class MediasController < Api::V1::BaseApiController
      include MediasDoc
      
      skip_before_filter :authenticate_from_token!, if: proc { request.format.html? || request.format.js? }
      after_action :allow_iframe, only: :index

      def index
        @url = params[:url]
        (render_parameters_missing and return) if @url.blank?
        @id = Digest::MD5.hexdigest(@url)
        @media = Media.new(url: @url)
        respond_to do |format|
          format.html { render_as_html }
          format.js   { render_as_js   }
          format.json { render_as_json }
        end
      end

      private

      def allow_iframe
        response.headers.except! 'X-Frame-Options'
      end

      def render_as_json
        begin
          render_success 'media', @media
        rescue
          render_error 'Could not parse this media', 'UNKNOWN'
        end
      end

      def render_as_html
        begin
          render template: 'medias/index', locals: { data: @media.as_json }
        rescue
          render html: 'Could not parse this media', status: 400
        end
      end

      def render_as_js
        @caller = request.original_url.gsub(/#.*/, '')
        render template: 'medias/index'
      end
    end
  end
end
