##
# Creates a new media based on a given url
#
# The url is visited, parsed and the data found is used to create a media
# and its attributes.
#
# The data can be obtained by +API+ or parsing directly the +HTML+.
#
# To avoid the duplication of media for the same url, it tries to find the
# canonical url and normalize it before parsing.
#
# There are specific parsers for +Youtube+, +Twitter+, +Facebook+, +Instagram+,
# +Dropbox+ and +oEmbed+.
# When the url cannot be parsed by a specific parser, it is parsed as a
# generic page.
#
# For every url, all the metatags are parsed from the page and merged to the
# media data.
# If the page has an oEmbed link, the oEmbed data is also retrieved and merged.
#
# If there's an error when parsing the url, the media is created with the
# minimal data and the error message is merged to the data.
#
# Parsing steps:
#  * Initialize
#    1. Follow the url redirections;
#    2. Parse the page and search if there is a canonical url on meta tags or
#    link tag to update the media url;
#    3. Escape and normalize the media url;
#    4. Try to convert the url to HTTPS;
#  * Parse as json
#    1. Set the minimal data for media
#    2. Search the page meta tags and store them on media
#    3. Search the page to find the oEmbed url and, if it exists, retrieve the
#    oEmbed data
#    4. Match the url with the patterns described on specific parsers
#    5. Parse the page with the parser found on previous step
#    6. Archives the page in background, for the archivers that apply to the current URL
#    7. Get metrics for the current URL, in background
#  * Parse as oEmbed
#    1. Get media the json data
#    2. If the page has an oEmbed url, request it and get the response
#    2. If the page doesn't have an oEmbed url, generate the oEmbed info based on the media json data

class Media
  [ActiveModel::Validations, ActiveModel::Conversion, MediasHelper, MediaOembed, MediaArchiver, MediaMetrics].each { |concern| include concern }
  extend ActiveModel::Naming

  attr_accessor :url, :provider, :type, :data, :request, :doc, :original_url, :key

  TYPES = {}

  LANG = 'en-US;q=0.6,en;q=0.4'

  def initialize(attributes = {})
    attributes.each do |name, value|
      send("#{name}=", value)
    end
    self.original_url = self.url.strip
    self.data = {}.with_indifferent_access
    self.follow_redirections
    self.url = Media.normalize_url(self.url) unless self.get_canonical_url
    self.try_https
  end

  def self.declare(type, patterns)
    TYPES[type] = patterns
  end

  def as_json(options = {})
    if options.delete(:force) || Pender::Store.read(Media.get_id(self.original_url), :json).nil?
      handle_exceptions(self, StandardError) { self.parse }
      data = self.data.merge(Media.required_fields(self)).with_indifferent_access

      Pender::Store.write(Media.get_id(self.original_url), :json, cleanup_data_encoding(data))
    end
    self.archive(options.delete(:archivers))
    self.get_metrics
    Pender::Store.read(Media.get_id(self.original_url), :json)
  end

  # Parsers and archivers
  [MediaYoutubeProfile, MediaYoutubeItem, MediaTwitterProfile, MediaTwitterItem, MediaFacebookProfile, MediaFacebookItem, MediaInstagramItem, MediaInstagramProfile, MediaDropboxItem, MediaTiktokItem, MediaTiktokProfile, MediaPageItem, MediaOembedItem, MediaScreenshotArchiver, MediaArchiveIsArchiver, MediaArchiveOrgArchiver, MediaHtmlPreprocessor, MediaSchemaOrg, MediaPermaCcArchiver, MediaVideoArchiver, MediaFacebookEngagementMetrics].each { |concern| include concern }

  def self.minimal_data(instance)
    data = {}
    %w(published_at username title description picture author_url author_picture author_name screenshot external_id html).each { |field| data[field] = '' }
    data[:raw] = {}
    data[:archives] = {}
    data[:metrics] = {}
    data.merge(Media.required_fields(instance)).with_indifferent_access
  end

  def self.required_fields(instance = nil)
    provider = instance.respond_to?(:provider) ? instance.provider : 'page'
    type = instance.respond_to?(:type) ? instance.type : 'item'
    {
      url: instance.url,
      provider: provider || 'page',
      type: type || 'item',
      parsed_at: Time.now.to_s,
      favicon: "https://www.google.com/s2/favicons?domain_url=#{instance.url.gsub(/^https?:\/\//, '')}"
    }
  end

  def self.validate_url(url)
    begin
      uri = URI.parse(URI.encode(url))
      return false unless (uri.kind_of?(URI::HTTP) || uri.kind_of?(URI::HTTPS))
      Media.request_url(url, 'Head')
    rescue OpenSSL::SSL::SSLError, URI::InvalidURIError, SocketError => e
      Airbrake.notify(e, url: url) if Airbrake.configured?
      Rails.logger.warn level: 'WARN', message: '[Parser] Invalid URL', url: url, error_class: e.class, error_message: e.message
      return false
    end
  end

  def self.get_id(url)
    Digest::MD5.hexdigest(Media.normalize_url(url))
  end

  def self.update_cache(url, newdata)
    id = Media.get_id(url)
    data = Pender::Store.read(id, :json)
    unless data.blank?
      newdata.each do |key, value|
        data[key] = data[key].is_a?(Hash) ? data[key].merge(value) : value
      end
      data['webhook_called'] = @webhook_called ? 1 : 0
      Pender::Store.write(id, :json, data)
    end
  end

  def self.notify_webhook(type, url, data, settings)
    if settings['webhook_url'] && settings['webhook_token']
      uri = URI.parse(settings['webhook_url'])
      payload = data.merge({ url: url, type: type }).to_json
      sig = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), settings['webhook_token'], payload)
      headers = { 'Content-Type': 'text/json', 'X-Signature': sig }
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      request = Net::HTTP::Post.new(uri.request_uri, headers)
      request.body = payload
      response = http.request(request)
      Rails.logger.info level: 'INFO', message: 'Webhook notification', url: url, type: type, code: response.code, response: response.message, webhook_url: settings['webhook_url']
      @webhook_called = true
    end
    true
  end

  protected

  def parse
    self.data.merge!(Media.minimal_data(self))
    get_metatags(self)
    get_jsonld_data(self)
    get_schema_data unless self.doc.nil?
    parsed = false
    TYPES.each do |type, patterns|
      patterns.each do |pattern|
        unless pattern.match(self.url).nil?
          self.provider, self.type = type.split('_')
          self.send("data_from_#{type}")
          self.get_oembed_data
          parsed = true
          break
        end
      end
      break if parsed
    end
    cleanup_html_entities(self)
  end

  ##
  # Parse the page and set it to media `doc`. If the `doc` has a tag (`og:url`, `twitter:url`, `rel='canonical`) with a different url, the media `url` is updated with the url found, the page is parsed and the media `doc` is updated

  def get_canonical_url
    self.doc = self.get_html(Media.html_options(self.url))
    if self.doc
      tag = self.doc.at_css("meta[property='og:url']") || self.doc.at_css("meta[property='twitter:url']") || self.doc.at_css("link[rel='canonical']")
      get_parsed_url(tag) unless tag.blank?
    end
  end

  def get_parsed_url(tag)
    canonical_url = tag.attr('content') || tag.attr('href')
    return false if canonical_url.blank?
    if canonical_url && canonical_url != self.url
      self.url = absolute_url(canonical_url)
      self.doc = self.get_html(Media.html_options(self.url))
    end
    true
  end

  def self.normalize_url(url)
    PostRank::URI.normalize(url).to_s
  end

  ##
  # Update the media `url` with the url found after all redirections

  def follow_redirections
    self.url = self.add_scheme(decoded_uri(self.url.strip))
    attempts = 0
    code = '301'
    path = []

    while attempts < 5 && %w(301 302).include?(code) && !path.include?(self.url)
      attempts += 1
      path << self.url
      response = self.request_media_url
      code = response.code
      self.set_url_from_location(response, path)
    end
  end

  def add_scheme(url)
    return url if url =~ /^https?:/
    'http://' + url
  end

  def set_url_from_location(response, path)
    if %w(301 302).include?(response.code)
      self.url = response.header['location']
      if self.url !~ /^https?:/
        self.url.prepend('/') unless self.url.match(/^\//)
        previous = path.last.match(/^https?:\/\/[^\/]+/)[0]
        self.url = previous + self.url
      end
    end
  end

  def request_media_url
    response = nil
    Retryable.retryable(tries: 3, sleep: 1) do
      response = Media.request_url(self.url, 'Head')
    end
    response
  end

  def self.request_url(url, verb = 'Get')
    uri = Media.parse_url(url)
    Media.request_uri(uri, verb)
  end

  def self.get_proxy(url)
    require 'uri'
    uri = URI.parse(URI.encode(url))
    ['proxy_host', 'proxy_port', 'proxy_pass', 'proxy_user_prefix'].each { |config| return nil if CONFIG.dig(config).blank? }
    return ["http://#{CONFIG['proxy_host']}:#{CONFIG['proxy_port']}", CONFIG['proxy_user_prefix'].gsub(/-country$/, "-session-#{Random.rand(100000)}"), CONFIG['proxy_pass']] if uri.host.match(/facebook\.com/)
    country = nil
    country = CONFIG['hosts'][uri.host]['country'] unless CONFIG.dig('hosts', uri.host, 'country').nil?
    return nil if country.nil?
    proxy_user = CONFIG['proxy_user_prefix'] + '-' + country
    ["http://#{CONFIG['proxy_host']}:#{CONFIG['proxy_port']}", proxy_user, CONFIG['proxy_pass']]
  end

  def self.request_uri(uri, verb)
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = CONFIG['timeout'] || 30
    http.use_ssl = uri.scheme == 'https'
    headers = { 'User-Agent' => Media.html_options(uri)['User-Agent'], 'Accept-Language' => LANG }.merge(Media.get_cf_credentials(uri))
    request = "Net::HTTP::#{verb}".constantize.new(uri, headers)
    request['Cookie'] = Media.set_cookies(uri)
    if uri.host.match(/facebook\.com/) && CONFIG['proxy_host']
      proxy = Net::HTTP::Proxy(CONFIG['proxy_host'], CONFIG['proxy_port'], CONFIG['proxy_user_prefix'].gsub(/-country$/, "-session-#{Random.rand(100000)}"), CONFIG['proxy_pass'])
      proxy.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http2|
        http2.request(request)
      end
    else
      http.request(request)
    end
  end

  def get_html(header_options = {})
    html = ''
    begin
      proxy = Media.get_proxy(self.url)
      options = header_options
      options = { proxy_http_basic_authentication: proxy, 'Accept-Language' => LANG } if proxy
      OpenURI.open_uri(Media.parse_url(decoded_uri(self.url)), options) do |f|
        f.binmode
        html = f.read
      end
      html = preprocess_html(html)
      Nokogiri::HTML html.gsub('<!-- <div', '<div').gsub('div> -->', 'div>')
    rescue OpenURI::HTTPError, Errno::ECONNRESET => e
      Airbrake.notify(e, url: self.url) if Airbrake.configured?
      Rails.logger.warn level: 'WARN', message: '[Parser] Could not get html', url: self.url, error_class: e.class, error_message: e.message
      self.data[:error] = { message: 'URL Not Found', code: LapisConstants::ErrorCodes::const_get('NOT_FOUND')}
      return nil
    rescue Zlib::DataError, Zlib::BufError
      self.get_html(Media.html_options(self.url).merge('Accept-Encoding' => 'identity'))
    rescue RuntimeError => e
      Airbrake.notify(e, url: self.url) if !redirect_https_to_http?(header_options, e.message) && Airbrake.configured?
      Rails.logger.warn level: 'WARN', message: '[Parser] Could not get html', url: self.url, error_class: e.class, error_message: e.message
      return nil
    end
  end

  def self.html_options(url)
    uri = url.is_a?(String) ? Media.parse_url(url) : url
    { allow_redirections: :safe, proxy: nil, 'User-Agent' => 'Mozilla/5.0 (X11)', 'Accept' => '*/*', 'Accept-Language' => LANG, 'Cookie' => Media.set_cookies(uri) }.merge(Media.get_cf_credentials(uri))
  end

  def self.get_cf_credentials(uri)
    unless CONFIG['hosts'].nil?
      config = CONFIG['hosts'][uri.host]
      if !config.nil? && config.has_key?('cf_credentials')
        id, secret = config['cf_credentials'].split(':')
        credentials = { 'CF-Access-Client-Id' => id, 'CF-Access-Client-Secret' => secret }
      end
    end
    credentials || {}
  end

  def top_url(url)
    uri = Media.parse_url(url)
    port = (uri.port == 80 || uri.port == 443) ? '' : ":#{uri.port}"
    "#{uri.scheme}://#{uri.host}#{port}"
  end

  def absolute_url(path = '')
    return self.url if path.blank?
    if path =~ /^https?:/
      path
    elsif path =~ /^\/\//
      Media.parse_url(self.url).scheme + ':' + path
    elsif path =~ /^www\./
      self.add_scheme(path)
    else
      self.top_url(self.url) + path
    end
  end

  def self.parse_url(url)
    URI.parse(URI.encode(url))
  end

  ##
  # Try to access the media `url` with HTTPS and it it succeeds, the media `url` is updated with the HTTPS version

  def try_https
    begin
      uri = URI.parse(self.url)
      unless (uri.kind_of?(URI::HTTPS))
        self.url.gsub!(/^http:/i, 'https:')
        Media.request_url(self.url, 'Head').value
      end
    rescue
      self.url.gsub!(/^https:/i, 'http:')
    end
  end

  def redirect_https_to_http?(header_options, message)
    message.match('redirection forbidden') && header_options[:allow_redirections] != :all
  end

  def self.set_cookies(uri)
    begin
      host = PublicSuffix.parse(uri.host).domain
      cookies = []
      CONFIG['cookies'].each do |domain, content|
        next unless domain.match(host)
        content.each { |k, v| cookies << "#{k}=#{v}" }
      end
      cookies.join('; ')
    rescue
      ''
    end
  end
end
