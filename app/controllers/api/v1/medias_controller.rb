require 'pender_exceptions'
require 'pender_store'
require 'cc_deville'
require 'semaphore'

module Api
  module V1
    class MediasController < Api::V1::BaseApiController
      include MediasHelper

      skip_before_action :authenticate_from_token!, if: proc { request.format.html? || request.format.js? || request.format.oembed? }
      before_action :strip_params, only: :index, if: proc { request.format.html? }
      before_action :get_params, only: [:index, :bulk]
      before_action :lock_url, only: :index
      after_action :allow_iframe, :unlock_url, only: :index

      def index
        @url = params[:url]

        rescue_block = Proc.new { |e| render_error e.message, 'UNKNOWN' }
        handle_exceptions(StandardError, rescue_block, {code: 'UNKNOWN'}) do
          (render_parameters_missing; return) if @url.blank?
          (render_url_invalid; return) unless is_url?(@url)

          @id = Media.get_id(@url)
          (render_uncached_media and return) if @refresh || Pender::Store.current.read(@id, :json).nil?
          respond_to do |format|
            %w(html js json oembed).each do |f|
              format.send(f) { send("render_as_#{f}") }
            end
          end
        end
      end

      def delete
        return unless request.format.json?
        urls = params[:url].is_a?(Array) ? params[:url] : params[:url].split(' ')
        urls.each do |url|
          @id = Media.get_id(url)
          cc_url = PenderConfig.get('public_url') + '/api/medias.html?url=' + url
          CcDeville.clear_cache_for_url(cc_url)
          Pender::Store.current.delete(@id, :json, :html)
        end
        render json: { type: 'success' }, status: 200
      end

      def bulk
        return unless request.format.json?
        urls = params[:url].is_a?(Array) ? params[:url] : params[:url].split(',').map(&:strip)
        result = { enqueued: [], failed: []}
        urls.each do |url|
          rescue_block = Proc.new { |_e| result[:failed] << url }
          handle_exceptions(StandardError, rescue_block, {url: url}) do
            @url = url
            MediaParserWorker.perform_async(url, ApiKey.current&.id, @refresh, @archivers)
            result[:enqueued] << url
          end
        end
        render_success 'success', result
      end

      private

      def render_uncached_media
        render_timeout(false) do
          (render_url_invalid and return true) unless valid_url?
          rescue_block = Proc.new { |_e| render_url_invalid and return true }
          handle_exceptions(OpenSSL::SSL::SSLError, rescue_block, {url: @url, request: request}) do
            @media = Media.new(url: @url, request: request)
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
          render_timeout(true) { render_media(@media.as_json({ force: @refresh, archivers: @archivers })) and return }
        rescue Pender::ApiLimitReached => e
          render_error e.reset_in, 'API_LIMIT_REACHED', 429
        rescue Pender::UnsafeUrl
          render_error 'Unsafe URL', 'UNSAFE', 400
        rescue StandardError => e
          data = get_error_data({ message: e.message, code: 'UNKNOWN' }, @media, @url, @id)
          notify_airbrake(e, data)
          Rails.logger.warn level: 'WARN', message: '[Rendering] Could not render media JSON data', error_class: e.class, error_message: e.message
          data.merge!(@data) unless @data.blank?
          data.merge!(@media.data) unless @media.blank?
          render_media(data)
        end
      end

      def render_timeout(must_render, oembed = false)
        data = Pender::Store.current.read(@id, :json)
        if !data.nil? && !@refresh
          render_timeout_media(data, must_render, oembed) and return true
        end
        begin
          yield
        rescue Net::ReadTimeout
          @data = get_timeout_data(nil, @url, @id)
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
        data ||= @data || {}
        data.merge!({ embed_tag: embed_url(request) })
        render_success 'media', data
      end

      def render_oembed(data, instance = nil)
        json = Media.as_oembed(data, request.original_url, params[:maxwidth], params[:maxheight], instance)
        render json: json, status: 200
      end

      def render_as_html
        begin
          if @refresh || !Pender::Store.current.exist?(@id, :html)
            save_cache
          end
          render plain: Pender::Store.current.read(@id, :html), status: 200
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
          render_timeout(true, true) { render_oembed(@media.as_json({ force: @refresh, archivers: @archivers }), @media)}
        rescue StandardError => e
          data = @media.nil? ? {} : @media.data
          data.merge!(error: { message: e.message, code: LapisConstants::ErrorCodes::const_get('UNKNOWN') })
          notify_airbrake(e, data)
          Rails.logger.warn level: 'WARN', message: '[Rendering] Could not render media oEmbed data', error_class: e.class, error_message: e.message
          render_media(data)
        end
      end

      def save_cache
        template = locals = nil
        cache = Pender::Store.current.read(@id, :json)
        data = cache && !@refresh ? cache : @media.as_json({ force: @refresh, archivers: @archivers })
        if should_serve_external_embed?(data)
          title = data['title'].truncate(50, separator: ' ')
          locals = { html: data['html'].html_safe, title: title }
          template = 'custom'
        else
          locals = { data: data }
          template = 'index'
        end

        content = generate_media_html(template, locals)

        Pender::Store.current.write(@id, :html, content)
        clear_upstream_cache if @refresh
      end

      def generate_media_html(template, locals)
        av = ActionView::Base.new(Rails.root.join('app', 'views'))
        av.assign(locals.merge({ request: request, id: @id, media: @media }))
        ActionView::Base.send :include, MediasHelper
        av.render(template: "medias/#{template}.html.erb", layout: 'layouts/application.html.erb')
      end

      def should_serve_external_embed?(data)
        !data['html'].blank? && (data['url'] =~ /^https:/ || Rails.env.development?)
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

      def clear_html_cache
        Pender::Store.current.delete(@id, :html)
        url = public_url(request).gsub(/medias(\.[a-z]+)?\?/, 'medias.html?')
        CcDeville.clear_cache_for_url(url)
      end

      def public_url(request)
        request.original_url.gsub(request.base_url, PenderConfig.get('public_url'))
      end

      def lock_url
        unless params[:url].blank?
          if locker.locked?
            error = { message: 'This URL is already being processed. Please try again in a few seconds.', code: 'DUPLICATED'}
            data = get_error_data(error, nil, params[:url])
            respond_to do |format|
              format.html { generate_media_html('index', { data: data }) }
              format.json { render_media(data) }
            end
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

      def strip_params
        rails_params = ['id', 'action', 'controller', 'format']
        supported_params = ['url', 'refresh', 'maxwidth', 'maxheight', 'version']
        url_params = params.keys - rails_params
        if (url_params & supported_params) == ['url'] && url_params.size > 1
          redirect_to(host: PenderConfig.get('public_url'), action: :index, format: :html, url: params[:url]) and return
        end
      end

      def notify_airbrake(e, extra_info = {})
        PenderAirbrake.notify(e, {url: @url}.merge(extra_info))
      end

      def handle_exceptions(exception, rescue_block, error_info = {})
        begin
          yield
        rescue exception => e
          error_info = { message: e.message }.merge(error_info)
          notify_airbrake(e, error_info)
          Rails.logger.warn level: 'WARN', message: "[Parser] Error on #{caller_locations(2).first.label}", error: error_info
          if LapisConstants::ErrorCodes::TEMP_ERRORS.include?(error_info.dig(:code))
            data = get_error_data(error_info, nil, @url, @id)
            render_media(data)
          else
            rescue_block.call(e)
          end
        end
      end
    end
  end
end
