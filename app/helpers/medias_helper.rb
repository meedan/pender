require 'htmlentities'

module MediasHelper
  def embed_url(request = @request)
    src = convert_url_to_format(request.original_url, 'js')
    "<script src=\"#{src}\" type=\"text/javascript\"></script>".html_safe
  end

  def convert_url_to_format(url, format)
    empty = ''.freeze
    url = url.sub(/medias([^\?]*)/, 'medias.' + format)
    if url =~ /refresh=1/
      url.sub!(/refresh=1/, empty)
      url.sub!(/medias\.#{format}\?/, "medias.#{format}?refresh=1&")
      url.sub!(/\&$/, empty)
    end
    url
  end

  def handle_exceptions(media, exception)
    begin
      yield
    rescue exception => error
      PenderAirbrake.notify(error, url: media.url, data: media.data )
      code = LapisConstants::ErrorCodes::const_get('UNKNOWN')
      media.data.merge!(error: { message: "#{error.class}: #{error.message}", code: code })
      Rails.logger.warn level: 'WARN', message: '[Parser] Could not parse', url: media.url, code: code, error_class: error.class, error_message: error.message
      return
    end
  end

  def get_metatags(media)
    media.data['raw']['metatags'] = []
    unless media.doc.nil?
      media.doc.search('meta').each do |meta|
        metatag = {}
        meta.each do |key, value|
          metatag.merge!({key.freeze => value.strip}) unless value.blank?
        end
        media.data['raw']['metatags'] << metatag
      end
    end
  end

  def get_jsonld_data(media)
    data = jsonld_tag_content(media)
    if data
      media.data['raw']['json+ld'] = data
      media.add_schema_to_data(media, data, data.dig('@type')) if (data.is_a?(Hash) && data.dig('@context')).match?('https?://schema.org')
    end
  end

  def jsonld_tag_content(media)
    tag = media.doc.at_css('script[type="application/ld+json"]')
    return if tag.blank? || tag.content == 'null'
    begin
      data = JSON.parse(tag.content)
      data = data[0] if data.is_a?(Array)
    rescue JSON::ParserError
      Rails.logger.warn level: 'WARN', message: '[Parser] Could not parse the JSON-LD content', url: media.url
    end
    data
  end

  def get_html_metadata(media, metatags)
    data = {}.with_indifferent_access
    metatags.each do |key, value|
      metatag = media.data['raw']['metatags'].find { |tag| tag['property'] == value || tag['name'] == value }
      data[key] = metatag['content'] if metatag
    end
    data
  end

  def get_info_from_data(source, data, *fields)
    empty = ''.freeze
    hash = data['raw'][source]
    return empty if hash.nil?
    fields.each do |field|
      return hash[field] if !hash[field].nil?
    end
    empty
  end

  ##
  # Remove HTML entities from standard text fields

  def cleanup_html_entities(media)
    %w(username title description author_name).each do |field|
      media.data[field] = HTMLEntities.new.decode(media.data[field])
    end
  end

  def decoded_uri(url)
    RequestHelper.decoded_uri(url)
  end

  def verify_published_time(time1, time2 = nil)
    return Time.at(time2.to_i) unless time2.nil?
    begin
      Time.parse(time1)
    rescue ArgumentError
      Time.at(time1.to_i)
    end
  end

  def is_url?(url)
    begin
      uri = URI.parse(URI.encode(url))
      !uri.host.nil? && uri.userinfo.nil?
    rescue URI::InvalidURIError
      false
    end
  end

  def get_error_data(error_data, media, url, id = nil)
    data = media.nil? ? Media.minimal_data(OpenStruct.new(url: url)) : media.data
    data['title'] = url if data['title'].blank?
    code = error_data[:code]
    error_data[:code] = LapisConstants::ErrorCodes::const_get(code)
    data = data.merge(error: error_data)
    Pender::Store.current.write(id, :json, data) unless code == 'DUPLICATED'
    data
  end

  def get_timeout_data(media, url, id)
    get_error_data({ message: 'Timeout', code: 'TIMEOUT' }, media, url, id)
  end

  def cleanup_data_encoding(data)
    data.each do |field, value|
      data[field] = cleanup_text(value, field)
    end
  end

  def cleanup_text(content, field = nil)
    if content.is_a?(String)
      content = content.encode("UTF-8", :invalid => :replace, :undef => :replace, :replace => "�".freeze)
      begin
        return URI.encode(content) if field == 'raw' && is_url?(content)
      rescue StandardError => error
        Rails.logger.info level: 'INFO', message: '[Parser] Could not encode URL', url: self.url, content: content, error_class: error.class, error_message: error.message
      end
    elsif content.respond_to?(:each_with_index)
      return cleanup_collection(content, field)
    end
    content
  end

  def cleanup_collection(content, field = nil)
    content.each_with_index do |(k, v), i|
      next if content.is_a?(Hash) && !v
      value = v || k
      index = content.is_a?(Hash) ? k : i
      content[index] = cleanup_text(value, field)
    end
    content
  end

  def upload_images
    id = Media.get_id(self.original_url)
    updates = {}
    [:author_picture, :picture].each do |attr|
      img_url = self.data.dig(attr)
      next if img_url.blank?
      parsed_url = Media.parse_url(img_url)
      if upload_image(id, attr, parsed_url)
        updates[attr] = self.data[attr]
      end
    end
    Media.update_cache(self.original_url, updates) unless updates.empty?
  end

  def upload_image(id, attr, url)
    extension = File.extname(url.path)
    extension = '.jpg' if extension.blank? || extension == '.php'
    filename = "#{id}/#{attr}#{extension}"
    begin
      open(url) do |content|
        Pender::Store.current.store_object(filename, content, 'medias/')
      end
      self.data[attr] = "#{Pender::Store.current.storage_path('medias')}/#{filename}"
      return true
    rescue StandardError => error
      PenderAirbrake.notify(StandardError.new("Could not get '#{attr}' image"), url: self.url, img_url: url, error: { class: error.class, message: error.message } )
      Rails.logger.warn level: 'WARN', message: "[Parser] Could not get '#{attr}' image", url: self.url, img_url: url, error_class: error.class, error_message: error.message
    end
  end

  def set_data_field(field, *values)
    return self.data[field] unless self.data[field].blank?
    values.each do |value|
      unless value.blank?
        self.data[field] = value
        break
      end
    end
  end

  # This will be replaced once parsers migrated, but 
  # we need different behavior here for now
  def ignore_url?(url)
    ignore_url = false
    # Media ignored URLs
    Media::TYPES.keys.map { |type| type[/(.+)_(item|profile)$/, 1] }.uniq.each do |provider|
      if self.respond_to?("ignore_#{provider}_urls")
        self.send("ignore_#{provider}_urls").each do |item|
          if url.match?(item[:pattern])
            ignore_url = true
            self.unavailable_page = item[:reason]
          end
        end
      end
    end
    # Parser ignored URLs
    Media::PARSERS.flat_map(&:ignored_urls).uniq.each do |item|
      if url.match?(item[:pattern])
        ignore_url = true
        self.unavailable_page = item[:reason]
      end
    end
    self.unavailable_page = nil unless ignore_url
    ignore_url
  end

  Media.class_eval do
    def self.decoded_uri(url)
      RequestHelper.decoded_uri(url)
    end

    def self.api_key_settings(key_id)
      key = ApiKey.where(id: key_id).last
      key ? key.settings : {}
    end

    def self.valid_proxy(config_key = 'proxy')
      RequestHelper.valid_proxy(config_key)
    end

    def self.get_proxy(uri, format = :array, force = false)
      RequestHelper.get_proxy(uri, format, force)
    end

    def self.proxy_format(proxy, format = :array)
      RequestHelper.valid_proxy(proxy, format)
    end

    def self.extended_headers(uri = nil)
      RequestHelper.extended_headers(uri)
    end
  end
end
