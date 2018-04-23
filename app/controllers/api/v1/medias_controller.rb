require 'timeout'
require 'pender_exceptions'
require 'cc_deville'
require 'semaphore'

module Api
  module V1
    class MediasController < Api::V1::BaseApiController
      include MediasDoc
      include MediasHelper

      skip_before_filter :authenticate_from_token!, if: proc { request.format.html? || request.format.js? || request.format.oembed? }
      before_action :strip_params, only: :index, if: proc { request.format.html? }
      before_action :lock_url, only: :index
      after_action :allow_iframe, :unlock_url, only: :index

      def index
        @url = params[:url]
        (render_parameters_missing; return) if @url.blank?
        (render_url_invalid; return) unless is_url?

        @refresh = params[:refresh] == '1'
        @id = Media.get_id(@url)

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
          @id = Media.get_id(url)
          Rails.cache.delete(@id)
          cc_url = CONFIG['public_url'] + '/api/medias.html?url=' + url
          CcDeville.clear_cache_for_url(cc_url)
          FileUtils.rm_f(cache_path)
        end
        render json: { type: 'success' }, status: 200
      end

      private

      def render_uncached_media
        render_timeout(false) do
          (render_url_invalid and return true) unless valid_url?
          begin
            @media = Media.new(url: @url, request: request, key: @key)
          rescue OpenSSL::SSL::SSLError
            render_url_invalid and return true
          end
        end and return true
        false
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
          data = get_error_data({ message: e.message, code: 'UNKNOWN' })
          data.merge!(@data) unless @data.blank?
          data.merge!(@media.data) unless @media.blank?
          render_media(data)
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
          @data = get_timeout_data
          render_timeout_media(@data, must_render) and return true
        end

        return false
      end

      def render_timeout_media(data, must_render, oembed = false)
        return false unless must_render
        oembed ? render_oembed(data) : render_media(data)
        return true
      end

      def render_media(data)
        json = { type: 'media' }
        json[:data] = data.merge({ embed_tag: embed_url(request) })
        render json: json, status: 200
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
        url = public_url(request)
        CcDeville.clear_cache_for_url(url)
        url_no_refresh = url.gsub(/&?refresh=1&?/, '')
        CcDeville.clear_cache_for_url(url_no_refresh) if url != url_no_refresh
      end

      def get_error_data(error_data)
        data = @media.nil? ? Media.minimal_data(OpenStruct.new(url: @url)) : @media.data
        data = data.merge(error: error_data)
        Rails.cache.write(@id, data)
        data
      end

      def get_timeout_data
        get_error_data({ message: 'Timeout', code: 'TIMEOUT' })
      end

      def clear_html_cache
        FileUtils.rm_f cache_path
        url = public_url(request).gsub(/medias(\.[a-z]+)?\?/, 'medias.html?')
        CcDeville.clear_cache_for_url(url)
      end

      def public_url(request)
        request.original_url.gsub(request.base_url, CONFIG['public_url'])
      end

      def lock_url
        unless params[:url].blank?
          if locker.locked?
            render_error('This URL is already being processed. Please try again in a few seconds.', 'DUPLICATED', 409) and return false
          else
            locker.lock
          end
        end
      end

      def unlock_url
        locker.unlock unless params[:url].blank?
      end

      def locker
        @locker ||= Semaphore.new(params[:url])
        @locker
      end

      def is_url?
        uri = URI.parse(URI.encode(@url))
        !uri.host.nil? && uri.userinfo.nil?
      end

      def strip_params
        rails_params = ['id', 'action', 'controller', 'format']
        supported_params = ['url', 'refresh', 'maxwidth', 'maxheight', 'version']
        url_params = params.keys - rails_params
        if (url_params & supported_params) == ['url'] && url_params.size > 1
          redirect_to(host: CONFIG['public_url'], action: :index, format: :html, url: params[:url]) and return
        end
      end
    end
  end
end
