class Media
  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend ActiveModel::Naming

  attr_accessor :url, :provider, :type, :data, :request, :doc

  TYPES = {}

  def initialize(attributes = {})
    attributes.each do |name, value|
      send("#{name}=", value)
    end
    self.follow_redirections
    self.normalize_url unless self.get_canonical_url
    self.try_https
    self.data = {}.with_indifferent_access
  end

  def self.declare(type, patterns)
    TYPES[type] = patterns
  end

  def as_json(options = {})
    Rails.cache.fetch(self.get_id, options) do
      self.parse
      self.data.merge(Media.required_fields(self)).with_indifferent_access
    end
  end

  include MediaYoutubeProfile
  include MediaYoutubeItem
  include MediaTwitterProfile
  include MediaTwitterItem
  include MediaFacebookProfile
  include MediaFacebookItem
  include MediaInstagramItem
  include MediaInstagramProfile
  include MediaBridgeItem
  include MediaPageItem
  include MediaOembedItem

  def as_oembed(original_url, maxwidth, maxheight, options = {})
    data = self.as_json(options)
    oembed = "#{data['provider']}_as_oembed"
    self.respond_to?(oembed)? self.send(oembed, original_url, maxwidth, maxheight) : self.default_oembed(original_url, maxwidth, maxheight)
  end

  def self.minimal_data(instance)
    data = {}
    %w(published_at username title description picture author_url author_picture).each do |field|
      data[field] = ''
    end
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
      favicon: "http://www.google.com/s2/favicons?domain_url=#{instance.url}"
    }
  end

  def handle_exceptions(exception, message_method = :message, code_method = :code)
    begin
      yield
    rescue exception => error
      code = error.respond_to?(code_method) ? error.send(code_method) : 5
      self.data.merge!(error: { message: "#{error.class}: #{error.send(message_method)}", code: code })
      return
    end
  end

  def self.validate_url(url)
    begin
      uri = URI.parse(url)
      return false unless (uri.kind_of?(URI::HTTP) || uri.kind_of?(URI::HTTPS))
      Media.request_uri(uri, 'Head')
    rescue URI::InvalidURIError, SocketError => e
      Rails.logger.warn "Could not access url: #{e.message}"
      return false
    end
  end

  protected

  def default_oembed(original_url, maxwidth, maxheight)
    maxwidth ||= 800
    maxheight ||= 200
    data = self.as_json
    src = original_url.gsub('medias.oembed', 'medias.html')
    {
      type: 'rich',
      version: '1.0',
      title: data['title'] || 'Pender',
      author_name: data['username'],
      author_url: (data['type'] === 'profile' ? data['url'] : ''),
      provider_name: data['provider'],
      provider_url: 'http://' + parse_url(data['url']).host,
      thumbnail_url: data['picture'],
      html: "<iframe src=\"#{src}\" width=\"#{maxwidth}\" height=\"#{maxheight}\" scrolling=\"no\" border=\"0\" seamless>Not supported</iframe>",
      width: maxwidth,
      height: maxheight
    }.with_indifferent_access
  end

  def get_id
    Digest::MD5.hexdigest(self.url)
  end

  def parse
    self.data = Media.minimal_data(self)
    parsed = false
    TYPES.each do |type, patterns|
      patterns.each do |pattern|
        unless pattern.match(self.url).nil?
          self.provider, self.type = type.split('_')
          self.send("data_from_#{type}")
          parsed = true
          break
        end
      end
      break if parsed
    end
  end

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

  def normalize_url
    self.url = PostRank::URI.normalize(self.url).to_s
  end

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
    uri = parse_url(self.url)
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
    request['Cookie'] = Media.set_cookies
    http.request(request)
  end

  def self.set_cookies
    cookies = []
    CONFIG['cookies'].each do |k, v|
      cookies << "#{k}=#{v}"
    end
    cookies.join('; ')
  end

  def get_html(header_options = {})
    html = ''
    begin
      open(parse_url(self.url), header_options) do |f|
        f.binmode
        html = f.read
      end
      doc = Nokogiri::HTML html.gsub('<!-- <div', '<div').gsub('div> -->', 'div>')
    rescue OpenURI::HTTPError
      return nil
    rescue Zlib::DataError
      self.get_html(html_options.merge('Accept-Encoding' => 'identity'))
    end
    doc
  end

  def html_options
    options = { allow_redirections: :safe }
    credentials = self.get_http_auth(parse_url(self.url))
    options[:http_basic_authentication] = credentials
    options['User-Agent'] = 'Mozilla/5.0 (Windows NT 5.2; rv:2.0.1) Gecko/20100101 Firefox/4.0.1'
    options['Accept-Language'] = 'en'
    options['Cookie'] = Media.set_cookies
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
    uri = parse_url(url)
    "#{uri.scheme}://#{uri.host}"
  end

  def absolute_url(path = '')
    return self.url if path.blank?
    if path =~ /^https?:/
      path
    elsif path =~ /^\/\//
      self.parse_url(self.url).scheme + ':' + path
    else
      self.top_url(self.url) + path
    end
  end

  def parse_url(url)
    URI.parse(URI.encode(url))
  end

  def try_https
    uri = URI.parse(self.url)
    unless (uri.kind_of?(URI::HTTPS))
      self.url.gsub!(/^http:/i, 'https:')
      uri = URI.parse(self.url)
      begin
        Media.request_uri(uri, 'Head')
      rescue
        self.url.gsub!(/^https:/i, 'http:')
      end
    end
  end
end
