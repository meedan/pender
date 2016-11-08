require 'timeout'
require 'pender_exceptions'

module Api
  module V1
    class MediasController < Api::V1::BaseApiController
      include MediasDoc
      include MediasHelper

      skip_before_filter :authenticate_from_token!, if: proc { request.format.html? || request.format.js? || request.format.oembed? }
      after_action :allow_iframe, only: :index

      def index
        @url = params[:url]
        @refresh = params[:refresh] == '1'
        (render_parameters_missing and return) if @url.blank?
        (render_url_invalid and return) unless valid_url?
        @id = Digest::MD5.hexdigest(@url)
        render_timeout { @media = Media.new(url: @url, request: request) } and return
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
        @request = request
        begin
          render_timeout { render_success('media', @media.as_json({ force: @refresh }).merge({ embed_tag: embed_url })) and return }
        rescue Pender::ApiLimitReached => e
          render_error e.reset_in, 'API_LIMIT_REACHED', 429
        rescue StandardError => e
          render_not_parseable(@media.data.merge(error: { message: e.message, code: 'UNKNOWN' }).merge({ embed_tag: embed_url }))
        end
      end

      def render_timeout
        timeout = CONFIG['timeout'] || 20
        begin
          Timeout::timeout(timeout) { yield }
          return false
        rescue Timeout::Error => e
          render_not_parseable({error: { message: "#{e.class}: #{e.message}", code: LapisConstants::ErrorCodes::const_get('TIMEOUT') }})
          return true
        end
      end

      def render_as_html
        begin
          unless File.exist?(cache_path)
            save_cache
          end
          render text: File.read(cache_path), status: 200
        rescue
          render html: 'Could not parse this media'
        end
      end

      def render_as_js
        @caller = request.original_url.gsub(/#.*/, '')
        render template: 'medias/index'
      end

      def render_as_oembed
        json = @media.as_oembed(request.original_url, params[:maxwidth], params[:maxheight], { force: @refresh })
        render json: json, status: 200
      end

      def save_cache
        av = ActionView::Base.new(Rails.root.join('app', 'views'))
        template = locals = nil
        data = @media.as_json({ force: @refresh })

        if !data['html'].blank?
          locals = { html: data['html'].html_safe }
          template = 'custom'
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

      def valid_url?
        begin
          uri = URI.parse(@url)
          return false unless (uri.kind_of?(URI::HTTP) || uri.kind_of?(URI::HTTPS))
          Net::HTTP.get_response(uri)
        rescue URI::InvalidURIError, SocketError, Errno::ECONNRESET => e
          Rails.logger.warn "Could not access url: #{e.message}"
          return false
        end
      end
    end
  end
end
