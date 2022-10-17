class RequestHelper
  REDIRECT_HTTP_CODES = %w(301 302 307 308).freeze

  class << self
    LANG = 'en-US;q=0.6,en;q=0.4'

    def get_html(url, set_error_callback, header_options = {}, force_proxy = false)
      begin
        uri = self.parse_url(self.decoded_uri(url))
        proxy = self.get_proxy(uri, :array, force_proxy)
        options = proxy ? { proxy_http_basic_authentication: proxy, 'Accept-Language' => LANG } : header_options
        html = ''.freeze
        OpenURI.open_uri(uri, options.merge(read_timeout: PenderConfig.get('timeout', 30).to_i)) do |f|
          f.binmode
          html = f.read
        end
        Nokogiri::HTML HtmlPreprocessor.preprocess_html(html)
      rescue OpenURI::HTTPError, Errno::ECONNRESET => e
        if force_proxy
          PenderAirbrake.notify(e, url: url)
          Rails.logger.warn level: 'WARN', message: '[Parser] Could not get html', url: url, error_class: e.class, error_message: e.message
          set_error_callback.call(message: 'URL Not Found', code: LapisConstants::ErrorCodes::const_get('NOT_FOUND'))
          return nil
        end
        get_html(url, set_error_callback, header_options, true)
      rescue Zlib::DataError, Zlib::BufError
        get_html(url, set_error_callback, self.html_options(url).merge('Accept-Encoding' => 'identity'))
      rescue RuntimeError => e
        PenderAirbrake.notify(e, url: url) if !redirect_https_to_http?(header_options, e.message)
        Rails.logger.warn level: 'WARN', message: '[Parser] Could not get html', url: url, error_class: e.class, error_message: e.message
        return nil
      end
    end

    def normalize_url(url)
      PostRank::URI.normalize(url).to_s
    end

    def html_options(url)
      uri = url.is_a?(String) ? self.parse_url(url) : url
      uri.host.match?(/twitter\.com/) ? self.extended_headers(url) : { allow_redirections: :safe, proxy: nil, 'User-Agent' => 'Mozilla/5.0 (X11)', 'Accept' => '*/*', 'Accept-Language' => LANG, 'Cookie' => self.set_cookies(uri) }.merge(self.get_cf_credentials(uri))
    end

    def parse_url(url)
      URI.parse(URI.encode(url))
    end

    def extended_headers(uri = nil)
      uri = self.parse_url(self.decoded_uri(uri)) if uri.is_a?(String)
      ({
        'User-Agent' => 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.125 Safari/537.36',
        'Accept' =>  'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
        'Accept-Language' => 'en-US',
        'Cookie' => self.set_cookies(uri)
      })
    end

    def absolute_url(url, path = '')
      return url if path.blank?
      if path =~ /^https?:/
        path
      elsif path =~ /^\/\//
        self.parse_url(url).scheme + ':' + path
      elsif path =~ /^www\./
        self.add_scheme(path)
      else
        self.top_url(url) + path
      end
    end

    def validate_url(url)
      begin
        uri = URI.parse(URI.encode(url))
        return false unless (uri.kind_of?(URI::HTTP) || uri.kind_of?(URI::HTTPS))
        self.request_url(url, 'Get')
      rescue OpenSSL::SSL::SSLError, URI::InvalidURIError, SocketError => e
        PenderAirbrake.notify(e, url: url)
        Rails.logger.warn level: 'WARN', message: '[Parser] Invalid URL', url: url, error_class: e.class, error_message: e.message
        return false
      end
    end

    def extended_headers(uri = nil)
      uri = self.parse_url(decoded_uri(uri)) if uri.is_a?(String)
      ({
        'User-Agent' => 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.125 Safari/537.36',
        'Accept' =>  'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9',
        'Accept-Language' => 'en-US',
        'Cookie' => self.set_cookies(uri)
      })
    end

    def get_proxy(uri, format = :array, force = false)
      proxy = self.valid_proxy
      if proxy || force
        country = force ? 'us' : PenderConfig.get('hosts', {}, :json).dig(uri.host, 'country')
        if uri.host.match?(/(facebook|tiktok|instagram)\.com/)
          proxy['user'] = proxy['user_prefix'] + proxy['country_prefix'] + 'us' + proxy['session_prefix'] + Random.rand(100000).to_s
        elsif country
          proxy['user'] = proxy['user_prefix'] + proxy['country_prefix'] + country
        end
        proxy_format(proxy, format)
      end
    end

    def request_url(url, verb = 'Get')
      uri = self.parse_url(self.decoded_uri(url))
      self.request_uri(uri, verb)
    end

    def request_uri(uri, verb = 'Get')
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = PenderConfig.get('timeout', 30).to_i
      http.use_ssl = uri.scheme == 'https'.freeze
      headers = { 'User-Agent' => self.html_options(uri)['User-Agent'], 'Accept-Language' => LANG }.merge(self.get_cf_credentials(uri))
      request = "Net::HTTP::#{verb}".constantize.new(uri, headers)
      request['Cookie'] = self.set_cookies(uri)
      proxy_config = self.get_proxy(uri, :hash)
      if proxy_config
        proxy = Net::HTTP::Proxy(proxy_config['host'], proxy_config['port'], proxy_config['user'], proxy_config['pass'])
        proxy.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http2|
          http2.request(request)
        end
      else
        http.request(request)
      end
    end

    def decoded_uri(url)
      begin
        URI.decode(url)
      rescue Encoding::CompatibilityError
        url
      end
    end

    def top_url(url)
      uri = self.parse_url(url)
      (uri.port == 80 || uri.port == 443) ? "#{uri.scheme}://#{uri.host}" : "#{uri.scheme}://#{uri.host}:#{uri.port}"
    end

    def add_scheme(url)
      return url if url =~ /^https?:/
      'http://' + url
    end
      
    def redirect_https_to_http?(header_options, message)
      message.match?('redirection forbidden') && header_options[:allow_redirections] != :all
    end

    def proxy_format(proxy, format = :array)
      return nil unless proxy['user']
      if format == :array
        ["http://#{proxy['host']}:#{proxy['port']}", proxy['user'], proxy['pass']]
      else
        proxy
      end
    end

    def get_cf_credentials(uri)
      hosts = PenderConfig.get('hosts', {}, :json)
      config = hosts[uri.host]
      if config && config.has_key?('cf_credentials')
        id, secret = config['cf_credentials'].split(':')
        credentials = { 'CF-Access-Client-Id' => id, 'CF-Access-Client-Secret' => secret }
      end
      credentials || {}
    end

    def valid_proxy(config_key = 'proxy')
      subkeys = [:host, :port, :pass, :user_prefix]
      subkeys += [:country_prefix, :session_prefix] if config_key == 'proxy'.freeze
      proxy = {}.with_indifferent_access
      subkeys.each do |config|
        value = PenderConfig.get("#{config_key}_#{config}")
        return nil if value.blank?
        proxy[config] = value
      end
      proxy
    end

    def set_cookies(uri)
      empty = ''.freeze
      begin
        host = PublicSuffix.parse(uri.host).domain
        cookies = []
        PenderConfig.get('cookies', {}).each do |domain, content|
          next unless domain.match?(host)
          content.each { |k, v| cookies << "#{k}=#{v}" }
        end
        cookies.empty? ? empty : cookies.join('; '.freeze)
      rescue
        empty
      end
    end
  end
end
