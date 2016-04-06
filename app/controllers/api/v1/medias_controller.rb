module Api
  module V1
    class MediasController < Api::V1::BaseApiController
      include MediasDoc
      
      skip_before_filter :authenticate_from_token!, if: proc { request.format.html? }

      def index
        url = params[:url]
        (render_parameters_missing and return) if url.blank?
        @media = Media.new(url: url)
        respond_to do |format|
          format.html { render_as_html }
          # format.js { render_as_js }
          format.json { render_as_json }
        end
      end

      private

      def render_as_json
        render_success 'media', @media
      end

      def render_as_html
        render template: 'medias/index', locals: { data: @media.as_json }
      end
    end
  end
end
