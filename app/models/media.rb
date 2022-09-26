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
# +Dropbox+, +TikTok+, and +oEmbed+.
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

require 'open_uri_redirections'
require 'postrank-uri'
require 'nokogiri'

class Media
  [ActiveModel::Validations, ActiveModel::Conversion, MediasHelper, MediaOembed, MediaArchiver].each { |concern| include concern }
  extend ActiveModel::Naming

  attr_accessor :url, :provider, :type, :data, :request, :doc, :original_url, :unavailable_page, :parser

  TYPES = {}

  LANG = 'en-US;q=0.6,en;q=0.4'

  def initialize(attributes = {})
    key = attributes.delete(:key)
    ApiKey.current = key if key
    attributes.each { |name, value| send("#{name}=", value) }
    self.original_url = self.url.strip
    self.data = {}.with_indifferent_access
    self.follow_redirections
    self.url = RequestHelper.normalize_url(self.url) unless self.get_canonical_url
    self.try_https
    self.parser = nil
  end

  def self.declare(type, patterns)
    TYPES[type] = patterns
  end

  def as_json(options = {})
    if options.delete(:force) || Pender::Store.current.read(Media.get_id(self.original_url), :json).nil?
      handle_exceptions(self, StandardError) { self.parse }
      self.data['title'] = self.url if self.data['title'].blank?
      data = self.data.merge(Media.required_fields(self)).with_indifferent_access
      if data[:error].blank?
        Pender::Store.current.write(Media.get_id(self.original_url), :json, cleanup_data_encoding(data))
      end
      self.upload_images
    end
    self.archive(options.delete(:archivers))
    Metrics.get_metrics_from_facebook_in_background(self.data, self.original_url, ApiKey.current&.id)
    Pender::Store.current.read(Media.get_id(self.original_url), :json) || cleanup_data_encoding(data)
  end

  PARSERS = [
    Parser::YoutubeProfile,
    Parser::YoutubeItem,
    Parser::TwitterProfile,
    Parser::TwitterItem,
    Parser::FacebookProfile,
    Parser::FacebookItem,
    Parser::InstagramItem,
    Parser::InstagramProfile,
    Parser::DropboxItem,
    Parser::TiktokItem,
    Parser::TiktokProfile,
    Parser::KwaiItem, 
    Parser::PageItem,
  ]

  [
    MediaArchiveIsArchiver, 
    MediaArchiveOrgArchiver, 
    MediaSchemaOrg, 
    MediaPermaCcArchiver, 
    MediaVideoArchiver, 
    MediaCrowdtangleItem
  ].each { |concern| include concern }

  def self.minimal_data(instance)
    data = {}
    %w(published_at username title description picture author_url author_picture author_name screenshot external_id html).each { |field| data[field.to_sym] = ''.freeze }
    data[:raw] = data[:archives] = data[:metrics] = {}
    data.merge(Media.required_fields(instance)).with_indifferent_access
  end

  def self.required_fields(instance = nil)
    provider = instance.respond_to?(:provider) ? instance.provider : 'page'
    type = instance.respond_to?(:type) ? instance.type : 'item'
    { url: instance.url, provider: provider || 'page', type: type || 'item', parsed_at: Time.now.to_s, favicon: "https://www.google.com/s2/favicons?domain_url=#{instance.url.gsub(/^https?:\/\//, ''.freeze)}" }
  end

  def self.get_id(url)
    Digest::MD5.hexdigest(RequestHelper.normalize_url(url))
  end

  def self.update_cache(url, newdata)
    id = Media.get_id(url)
    data = Pender::Store.current.read(id, :json)
    unless data.blank?
      newdata.each { |key, value| data[key] = data[key].is_a?(Hash) ? data[key].merge(value) : value }
      data['webhook_called'] = @webhook_called ? 1 : 0
      Pender::Store.current.write(id, :json, data)
    end
    data
  end

  def self.notify_webhook(type, url, data, settings)
    if settings['webhook_url'] && settings['webhook_token']
      begin
        uri = URI.parse(settings['webhook_url'])
        payload = data.merge({ url: url, type: type }).to_json
        sig = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), settings['webhook_token'], payload)
        headers = { 'Content-Type': 'text/json', 'X-Signature': sig }
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        request = Net::HTTP::Post.new(uri.request_uri, headers)
        request.body = payload
        http.request(request)
        @webhook_called = true
      rescue StandardError => e
        PenderAirbrake.notify(e, url: url, type: type, webhook_url: settings['webhook_url'])
        Rails.logger.warn level: 'WARN', message: 'Failed to notify webhook', url: url, type: type, error_class: e.class, error_message: e.message, webhook_url: settings['webhook_url']
        return false
      end
    else
      Rails.logger.warn level: 'WARN', message: 'Webhook settings not configured for API key', url: url, type: type, api_key: ApiKey.current&.id
    end
    true
  end

  protected

  def parse
    self.data.merge!(Media.minimal_data(self))
    get_jsonld_data(self) unless self.doc.nil?
    get_schema_data unless self.doc.nil?
    parsed = false

    PARSERS.each do |parser|
      if parseable = parser.match?(self.url)
        self.parser = parseable
        self.provider, self.type = self.parser.type.split('_')
        self.data.deep_merge!(self.parser.parse_data(self.doc, self.original_url, self.data.dig('raw', 'json+ld')))
        self.url = self.parser.url
        self.get_oembed_data
        parsed = true
      end
      break if parsed
    end

    cleanup_html_entities(self)
  end

  ##
  # Parse the page and set it to media `doc`. If the `doc` has a tag (`og:url`, `twitter:url`, `rel='canonical`) with a different url, the media `url` is updated with the url found, the page is parsed and the media `doc` is updated

  def get_canonical_url
    self.doc = self.get_html(RequestHelper.html_options(self.url))
    tag = self.doc&.at_css("meta[property='og:url']") || self.doc&.at_css("meta[property='twitter:url']") || self.doc&.at_css("link[rel='canonical']")
    canonical_url = tag&.attr('content') || tag&.attr('href')
    get_parsed_url(canonical_url) if canonical_url
  end

  def get_parsed_url(canonical_url)
    return false if !RequestHelper.validate_url(canonical_url)
    if canonical_url != self.url && !self.ignore_url?(canonical_url)
      self.url = RequestHelper.absolute_url(self.url, canonical_url)
      self.doc = self.get_html(RequestHelper.html_options(self.url)) if self.doc.nil?
    end
    true
  end

  ##
  # Update the media `url` with the url found after all redirections

  def follow_redirections
    self.url = RequestHelper.add_scheme(RequestHelper.decoded_uri(self.url.strip))
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

  def set_url_from_location(response, path)
    if %w(301 302).include?(response.code)
      self.url = response.header['location'] unless self.ignore_url?(response.header['location'])
      if self.url !~ /^https?:/
        self.url.prepend('/') unless self.url.match?(/^\//)
        previous = path.last.match(/^https?:\/\/[^\/]+/)[0]
        self.url = previous + self.url
      end
    end
  end

  def request_media_url
    response = nil
    Retryable.retryable(tries: 3, sleep: 1, :not => [Net::ReadTimeout]) do
      response = RequestHelper.request_url(url, 'Get')
    end
    response
  end

  ##
  # Try to access the media `url` with HTTPS and it it succeeds, the media `url` is updated with the HTTPS version

  def try_https
    # Makes modifications to URL behavior
    begin
      uri = URI.parse(self.url)
      unless (uri.kind_of?(URI::HTTPS))
        self.url.gsub!(/^http:/i, 'https:')
        RequestHelper.request_url(self.url, 'Get').value
      end
    rescue
      self.url.gsub!(/^https:/i, 'http:')
    end
  end

  def get_html(header_options = {}, force_proxy = false)
    RequestHelper.get_html(self.url, self.method(:set_error), header_options, force_proxy)
  end

  def set_error(**error_hash)
    return if error_hash.empty?
    self.data[:error] = error_hash
  end
end
