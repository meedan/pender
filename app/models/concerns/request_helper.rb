require 'postrank-uri'

class RequestHelper
  REDIRECT_HTTP_CODES = %w(301 302 307 308).freeze
  class UrlFormatError < StandardError; end

  class << self
    LANG = 'en-US;q=0.6,en;q=0.4'

    def get_html(url, set_error_callback, header_options = {}, force_proxy = false)
      begin
        uri = self.parse_url(url)
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
          PenderSentry.notify(e, url: url)
          Rails.logger.warn level: 'WARN', message: '[Parser] Could not get html', url: url, error_class: e.class, error_message: e.message
          set_error_callback.call(message: 'URL Not Found', code: Lapis::ErrorCodes::const_get('NOT_FOUND'))
          return nil
        end
        get_html(url, set_error_callback, header_options, true)
      rescue Net::HTTPClientException => e
        handle_http_exception_error(e)
      rescue Zlib::DataError, Zlib::BufError
        get_html(url, set_error_callback, self.html_options(url).merge('Accept-Encoding' => 'identity'))
      rescue EOFError, Net::ReadTimeout => e
        PenderSentry.notify(e, url: url)
        Rails.logger.warn level: 'WARN', message: '[Parser] Could not get html', url: url, error_class: e.class, error_message: e.message
        return nil
      rescue RuntimeError => e
        if !redirect_https_to_http?(header_options, e.message)
          PenderSentry.notify(e, url: url)
        end
        Rails.logger.warn level: 'WARN', message: '[Parser] Could not get html', url: url, error_class: e.class, error_message: e.message
        return nil
      end
    end

    def normalize_url(url)
      # This does a more intensive PostRank normalization, including stripping params
      # and pre-pending http/https if needed
      # https://github.com/postrank-labs/postrank-uri/blob/master/lib/postrank-uri.rb#L154
      begin
        PostRank::URI.normalize(url).to_s
      rescue Addressable::URI::InvalidURIError, NoMethodError, TypeError => e
        raise UrlFormatError.new(e)
      end
    end

    def html_options(url)
      uri = url.is_a?(String) ? self.parse_url(url) : url
      uri.host.match?(/twitter\.com/) ? self.extended_headers(url) : { allow_redirections: :safe, proxy: nil, 'User-Agent' => 'Mozilla/5.0 (X11)', 'Accept' => '*/*', 'Accept-Language' => LANG, 'Cookie' => self.set_cookies(uri) }.merge(self.get_cf_credentials(uri))
    end

    def encode_url(url)
      Addressable::URI.encode(url)
    end

    def parse_url(url)
      # This does basic addressable normalizing, mimicking
      # what PostRank does in its parsing (except this does not prefix http
      # in front of any schemeless URIs, which was giving us problems for canonical urls)
      # Addressable: https://www.rubydoc.info/gems/addressable/Addressable/URI#parse-class_method
      # PostRank: https://github.com/postrank-labs/postrank-uri/blob/master/lib/postrank-uri.rb#L198
      begin
        uri = Addressable::URI.parse(url)
        uri.normalize!
      rescue Addressable::URI::InvalidURIError, NoMethodError, TypeError => e
        raise UrlFormatError.new(e)
      end
    end

    def extended_headers(uri = nil)
      uri = self.parse_url(self.decode_uri(uri)) if uri.is_a?(String)
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
        uri = RequestHelper.parse_url(url)
        return false unless (uri.scheme && uri.scheme.starts_with?('http'))
        self.request_url(url, 'Get')
      rescue OpenSSL::SSL::SSLError, UrlFormatError, SocketError => e
        PenderSentry.notify(e, url: url)
        Rails.logger.warn level: 'WARN', message: '[Parser] Invalid URL', url: url, error_class: e.class, error_message: e.message
        return false
      end
    end

    def get_proxy(uri, format = :array, force = false)
      proxy = self.valid_proxy
      if proxy || force
        country = force ? 'us' : PenderConfig.get('hosts', {}, :json).dig(uri.host, 'country')
        if uri.host.match?(/(tiktok)\.com/)
          proxy['user'] = proxy['user_prefix'] + proxy['country_prefix'] + 'us' + proxy['session_prefix'] + Random.rand(100000).to_s
        elsif country
          proxy['user'] = proxy['user_prefix'] + proxy['country_prefix'] + country
        end
        proxy_format(proxy, format)
      end
    end

    def request_url(url, verb = 'Get')
      uri = self.parse_url(url)
      begin
        self.request_uri(uri, verb)
      rescue Net::HTTPClientException => e
        handle_http_exception_error(e)
        self.request_uri(uri, verb, skip_proxy = true) # retries without the proxy
      end
    end

    def request_uri(uri, verb = 'Get', skip_proxy = false)
      http = self.initialize_http(uri, skip_proxy)
      headers = {
        'User-Agent' => self.html_options(uri)['User-Agent'],
        'Accept-Language' => LANG,
      }.merge(self.get_cf_credentials(uri))

      request = "Net::HTTP::#{verb}".constantize.new(uri.to_s, headers)
      request['Cookie'] = self.set_cookies(uri)

      http.request(request)
    end

    def initialize_http(uri, skip_proxy = false)
      http = Net::HTTP.new(uri.host, uri.inferred_port)
      proxy_config = self.get_proxy(uri, :hash)
      if proxy_config && !skip_proxy
        http = Net::HTTP.new(uri.host, uri.inferred_port, proxy_config['host'], proxy_config['port'], proxy_config['user'], proxy_config['pass'])
      end
      http.read_timeout = PenderConfig.get('timeout', 30).to_i
      http.use_ssl = uri.scheme == 'https'.freeze

      http
    end

    def decode_uri(url)
      begin
        Addressable::URI.unencode(url)
      rescue Addressable::URI::InvalidURIError, NoMethodError, TypeError
        url
      end
    end

    def top_url(url)
      uri = self.parse_url(url)
      (uri.inferred_port == 80 || uri.inferred_port == 443) ? "#{uri.scheme}://#{uri.host}" : "#{uri.scheme}://#{uri.host}:#{uri.inferred_port}"
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
        host = uri.domain
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

  def handle_http_exception_error(error)
    PenderSentry.notify(e, url: url)
    Rails.logger.warn level: 'WARN', message: '[Parser] Could not get html', url: url, error_class: e.class, error_message: e.message
    set_error_callback.call(message: 'Proxy Error', code: Lapis::ErrorCodes::const_get('LOGIN_REQUIRED'))
    return nil
  end
end
