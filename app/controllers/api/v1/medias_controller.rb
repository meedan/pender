require 'timeout'
require 'pender_exceptions'
require 'cc_deville'

module Api
  module V1
    class MediasController < Api::V1::BaseApiController
      include MediasDoc
      include MediasHelper

      skip_before_filter :authenticate_from_token!, if: proc { request.format.html? || request.format.js? || request.format.oembed? }
      after_action :allow_iframe, only: :index

      def index
        @url = params[:url]
        (render_parameters_missing and return) if @url.blank?
        
        @refresh = params[:refresh] == '1'
        @id = Digest::MD5.hexdigest(@url)
        (render_uncached_media and return) if @refresh || Rails.cache.read(@id).nil?

        respond_to do |format|
          list_formats.each do |f|
            format.send(f) { send("render_as_#{f}") }
          end
        end
      end

      def delete
        return unless request.format.json?
        urls = params[:url].is_a?(Array) ? params[:url] : params[:url].split(' ')
        urls.each do |url|
          @id = Digest::MD5.hexdigest(url)
          Rails.cache.delete(@id)
          cc_url = request.domain + '/api/medias.html?url=' + url
          CcDeville.clear_cache_for_url(cc_url)
          FileUtils.rm_f(cache_path)
        end
        render json: { type: 'success' }, status: 200
      end

      private

      def render_uncached_media
        render_timeout(false) do
          (render_url_invalid and return true) unless valid_url?
          @media = Media.new(url: @url, request: request)
        end and return true
        false
      end

      def list_formats
        %w(html js json oembed)
      end

      def allow_iframe
        response.headers.except! 'X-Frame-Options'
      end

      def render_as_json
        @request = request
        begin
          clear_html_cache if @refresh
          render_timeout(true) { render_media(@media.as_json({ force: @refresh })) and return }
        rescue Pender::ApiLimitReached => e
          render_error e.reset_in, 'API_LIMIT_REACHED', 429
        rescue StandardError => e
          data = @media.nil? ? {} : @media.data
          render_media(data.merge(error: { message: e.message, code: 'UNKNOWN' }))
        end
      end

      def render_timeout(must_render, oembed = false)
        data = Rails.cache.read(@id)
        if !data.nil? && !@refresh
          render_timeout_media(data, must_render, oembed) and return true
        end
        
        begin
          Timeout::timeout(timeout_value) { yield }
        rescue Timeout::Error
          data = get_timeout_data
          render_timeout_media(data, must_render) and return true
        end
          
        return false
      end

      def render_timeout_media(data, must_render, oembed)
        return false unless must_render
        oembed ? render_oembed(data) : render_media(data)
        return true
      end

      def render_media(data)
        json = { type: 'media' }
        json[:data] = data.merge({ embed_tag: embed_url(request) })
        render json: data, status: 200
      end

      def render_oembed(data, instance = nil)
        json = Media.as_oembed(data, request.original_url, params[:maxwidth], params[:maxheight], instance)
        render json: json, status: 200
      end

      def render_as_html
        begin
          if @refresh || !File.exist?(cache_path)
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
        begin
          render_timeout(true, true) { render_oembed(@media.as_json({ force: @refresh }), @media)}
        rescue StandardError => e
          data = @media.nil? ? {} : @media.data
          Airbrake.notify(e) if Airbrake.configuration.api_key
          render_media(data.merge(error: { message: e.message, code: 'UNKNOWN' }))
        end
      end

      def save_cache
        av = ActionView::Base.new(Rails.root.join('app', 'views'))
        template = locals = nil
        cache = Rails.cache.read(@id)
        data = cache && !@refresh ? cache : @media.as_json({ force: @refresh })

        if should_serve_external_embed?(data)
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
        clear_upstream_cache if @refresh
      end

      def should_serve_external_embed?(data)
        !data['html'].blank? && (data['url'] =~ /^https:/ || Rails.env.development?)
      end

      def cache_path
        dir = File.join('public', 'cache', Rails.env)
        FileUtils.mkdir_p(dir) unless File.exist?(dir)
        File.join(dir, "#{@id}.html")
      end

      def valid_url?
        Media.validate_url(@url)
      end

      def clear_upstream_cache
        url = request.original_url
        CcDeville.clear_cache_for_url(url)
        url_no_refresh = url.gsub(/&?refresh=1&?/, '')
        CcDeville.clear_cache_for_url(url_no_refresh) if url != url_no_refresh
      end

      def get_timeout_data
        data = @media.nil? ? Media.minimal_data(OpenStruct.new(url: @url)) : @media.data
        data = data.merge(error: { message: 'Timeout', code: 'TIMEOUT' })
        Rails.cache.write(@id, data)
        data
      end

      def clear_html_cache
        FileUtils.rm_f cache_path
        url = request.original_url.gsub(/medias(\.[a-z]+)?\?/, 'medias.html?')
        CcDeville.clear_cache_for_url(url)
      end
    end
  end
end
