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
# +Bridge+, +Dropbox+ and +oEmbed+.
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
#    6. Generate screenshot in background
#  * Parse as oEmbed
#    1. Get media the json data
#    2. If the page has an oEmbed url, request it and get the response
#    2. If the page doesn't have an oEmbed url, generate the oEmbed info based on the media json data

class Media
  include ActiveModel::Validations
  include ActiveModel::Conversion
  include MediasHelper
  extend ActiveModel::Naming

  attr_accessor :url, :provider, :type, :data, :request, :doc, :original_url, :key

  TYPES = {}

  def initialize(attributes = {})
    attributes.each do |name, value|
      send("#{name}=", value)
    end
    self.original_url = self.url.strip
    self.follow_redirections
    self.url = Media.normalize_url(self.url) unless self.get_canonical_url
    self.try_https
    self.data = {}.with_indifferent_access
  end

  def self.declare(type, patterns)
    TYPES[type] = patterns
  end

  def as_json(options = {})
    Rails.cache.fetch(Media.get_id(self.original_url), options) do
      self.parse
      self.generate_screenshot
      self.data.merge(Media.required_fields(self)).with_indifferent_access
    end
  end

  [MediaYoutubeProfile, MediaYoutubeItem, MediaTwitterProfile, MediaTwitterItem, MediaFacebookProfile, MediaFacebookItem, MediaInstagramItem, MediaInstagramProfile, MediaBridgeItem, MediaDropboxItem, MediaPageItem, MediaOembedItem].each do |concern|
    include concern
  end

  def self.as_oembed(data, original_url, maxwidth, maxheight, instance = nil)
    return instance.send(:get_oembed_data, original_url, maxwidth, maxheight) if instance
    if data[:raw].nil? || data[:raw][:oembed].nil?
      Media.default_oembed(data, original_url, maxwidth, maxheight)
    else
      data[:raw][:oembed].merge(width: maxwidth, height: maxheight, html: Media.default_oembed_html(original_url, maxwidth, maxheight))
    end
  end

  def self.minimal_data(instance)
    data = {}
    %w(published_at username title description picture author_url author_picture author_name screenshot).each do |field|
      data[field] = ''
    end
    data[:raw] = {}
    data.merge(Media.required_fields(instance)).with_indifferent_access
  end

  def self.required_fields(instance = nil)
    provider = instance.respond_to?(:provider) ? instance.provider : 'page'
    type = instance.respond_to?(:type) ? instance.type : 'item'
    {
      url: instance.url,
      provider: provider || 'page',
      type: type || 'item',
      parsed_at: Time.now,
      favicon: "https://www.google.com/s2/favicons?domain_url=#{instance.url.gsub(/^https?:\/\//, '')}"
    }
  end

  def self.validate_url(url)
    begin
      uri = URI.parse(URI.encode(url))
      return false unless (uri.kind_of?(URI::HTTP) || uri.kind_of?(URI::HTTPS))
      Media.request_uri(uri, 'Head')
    rescue OpenSSL::SSL::SSLError, URI::InvalidURIError, SocketError => e
      Rails.logger.warn "Could not access url: #{e.message}"
      return false
    end
  end

  def self.default_oembed(data, original_url, maxwidth = nil, maxheight= nil)
    maxwidth ||= 800
    maxheight ||= 200
    src = original_url.gsub('medias.oembed', 'medias.html')
    {
      type: 'rich',
      version: '1.0',
      title: data['title'] || 'Pender',
      author_name: data['username'],
      author_url: (data['type'] === 'profile' ? data['url'] : ''),
      provider_name: data['provider'],
      provider_url: 'http://' + Media.parse_url(data['url']).host,
      thumbnail_url: data['picture'],
      html: Media.default_oembed_html(src, maxwidth, maxheight),
      width: maxwidth,
      height: maxheight
    }.with_indifferent_access
  end

  def self.default_oembed_html(src, maxwidth = 800, maxheight = 200)
    "<iframe src=\"#{src}\" width=\"#{maxwidth}\" height=\"#{maxheight}\" scrolling=\"no\" border=\"0\" seamless>Not supported</iframe>"
  end

  def self.get_id(url)
    Digest::MD5.hexdigest(Media.normalize_url(url))
  end

  protected

  def parse
    self.data = Media.minimal_data(self)
    get_metatags(self)
    get_jsonld_data(self)
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
    self.doc = self.get_html(html_options)
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
      self.doc = self.get_html(html_options)
    end
    true
  end

  def self.normalize_url(url)
    PostRank::URI.normalize(url).to_s
  end

  ##
  # Update the media `url` with the url found after all redirections

  def follow_redirections
    self.url = self.add_scheme(URI.decode(self.url.strip))
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
      if self.url =~ /^\//
        previous = path.last.match(/^https?:\/\/[^\/]+/)[0]
        self.url = previous + self.url
      end
    end
  end

  def request_media_url
    uri = Media.parse_url(self.url)
    response = nil
    Retryable.retryable(tries: 3, sleep: 1) do
      response = Media.request_uri(uri, 'Head')
    end
    response
  end

  def self.request_uri(uri, verb = 'Get')
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = CONFIG['timeout'] || 30
    http.use_ssl = uri.scheme == 'https'
    request = "Net::HTTP::#{verb}".constantize.new(uri.request_uri)
    http.request(request)
  end

  def get_html(header_options = {})
    html = ''
    begin
      OpenURI.open_uri(Media.parse_url(self.url), header_options) do |f|
        f.binmode
        html = f.read
      end
      Nokogiri::HTML html.gsub('<!-- <div', '<div').gsub('div> -->', 'div>')
    rescue OpenURI::HTTPError, Errno::ECONNRESET
      return nil
    rescue Zlib::DataError
      self.get_html(html_options.merge('Accept-Encoding' => 'identity'))
    rescue RuntimeError => e
      Airbrake.notify(e) if !redirect_https_to_http?(header_options, e.message) && Airbrake.configuration.api_key
      return nil
    end
  end

  def html_options
    options = { allow_redirections: :safe }
    credentials = self.get_http_auth(Media.parse_url(self.url))
    options[:http_basic_authentication] = credentials
    options['User-Agent'] = 'Mozilla/5.0 (Windows NT 5.2; rv:2.0.1) Gecko/20100101 Firefox/4.0.1'
    options['Accept-Language'] = 'en'
    options
  end

  def get_http_auth(uri)
    credentials = nil
    unless CONFIG['hosts'].nil?
      config = CONFIG['hosts'][uri.host]
      unless config.nil?
        credentials = config['http_auth'].split(':')
      end
    end
    credentials
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
        uri = URI.parse(self.url)
        Media.request_uri(uri, 'Head')
      end
    rescue
      self.url.gsub!(/^https:/i, 'http:')
    end
  end

  def get_oembed_data(original_url = nil, maxwidth = nil, maxheight= nil)
    url = original_url || self.url
    if !self.data['raw'].nil? && !self.data['raw']['oembed'].nil?
      self.data['raw']['oembed'].merge(width: maxwidth, height: maxheight, html: Media.default_oembed_html(url, maxwidth, maxheight))
    else
      self.as_json if self.data.empty?
      %w(type provider).each { |key| self.data[key] = self.send(key.to_sym) }
      self.data['raw']['oembed'] = Media.default_oembed(self.data, url, maxwidth, maxheight) unless self.data_from_oembed_item
    end
    self.data['raw']['oembed']
  end

  def redirect_https_to_http?(header_options, message)
    message.match('redirection forbidden') && header_options[:allow_redirections] != :all
  end

  def generate_screenshot
    url = self.url
    filename = url.parameterize + '.png'
    base_url = CONFIG['public_url'] || self.request.base_url
    picture = URI.join(base_url, 'screenshots/', filename).to_s
    path = File.join(Rails.root, 'public', 'screenshots', filename)
    FileUtils.rm_f path
    FileUtils.ln_s File.join(Rails.root, 'public', 'pending_picture.png'), path 
    self.data['screenshot'] = picture
    self.data['screenshot_taken'] = 0
    key_id = self.key ? self.key.id : nil
    ScreenshotWorker.perform_async(url, picture, key_id)
  end
end
