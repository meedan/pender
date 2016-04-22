module Api
  module V1
    class MediasController < Api::V1::BaseApiController
      include MediasDoc
      
      skip_before_filter :authenticate_from_token!, if: proc { request.format.html? || request.format.js? || request.format.oembed? }
      after_action :allow_iframe, only: :index

      def index
        @url = params[:url]
        (render_parameters_missing and return) if @url.blank?
        @id = Digest::MD5.hexdigest(@url)
        @media = Media.new(url: @url)
        respond_to do |format|
          format.html   { render_as_html   }
          format.js     { render_as_js     }
          format.json   { render_as_json   }
          format.oembed { render_as_oembed }
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
          @cache = true
          unless File.exist?(cache_path)
            @cache = false
            save_cache
          end
          render text: File.read(cache_path), status: 200
        rescue
          render html: 'Could not parse this media', status: 400
        end
      end

      def render_as_js
        @caller = request.original_url.gsub(/#.*/, '')
        render template: 'medias/index'
      end

      def render_as_oembed
        json = @media.as_oembed(request.original_url, params[:maxwidth], params[:maxheight])
        render json: json, status: 200
      end

      def save_cache
        av = ActionView::Base.new(Rails.root.join('app', 'views'))
        template = locals = nil
        data = @media.as_json
        oembed = data[:oembed]

        if oembed && oembed['html']
          locals = { html: oembed['html'].html_safe }
          template = 'oembed'
        else
          locals = { data: data }
          template = 'index'
        end

        av.assign(locals.merge({ request: request, id: @id, media: @media }))
        ActionView::Base.send :include, MediasHelper
        content = av.render(template: "medias/#{template}.html.erb", layout: 'layouts/application.html.erb')
        File.atomic_write(cache_path) { |file| file.write(content) }
      end

      def cache_path
        name = Digest::MD5.hexdigest(@url)
        dir = File.join('public', 'cache', Rails.env)
        FileUtils.mkdir_p(dir) unless File.exist?(dir)
        File.join(dir, "#{name}.html")
      end
    end
  end
end
