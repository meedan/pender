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
      PenderSentry.notify(error, url: media.url, data: media.data)
      code = Lapis::ErrorCodes::const_get('UNKNOWN')
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
    media.data['raw']['json+ld'] = []
    data_array = jsonld_tag_content(media)
    data_array.each { |data| media.data['raw']['json+ld'] << data }
  end

  def jsonld_tag_content(media)
    tags = media.doc.css('script[type="application/ld+json"]')
    tags_with_content = tags.reject{|t| t.content == 'null' }
    data_array = []
    begin
      data_array = tags_with_content.map { |tag| JSON.parse(tag.content) }
    rescue JSON::ParserError
      Rails.logger.warn level: 'WARN', message: '[Parser] Could not parse the JSON-LD content', url: media.url
    end
    data_array
  end

  ##
  # Remove HTML entities from standard text fields

  def cleanup_html_entities(media)
    %w(username title description author_name).each do |field|
      media.data[field] = HTMLEntities.new.decode(media.data[field])
    end
  end

  def is_url?(url)
    begin
      uri = RequestHelper.parse_url(url)
      !uri.host.nil? && uri.userinfo.nil?
    rescue RequestHelper::UrlFormatError
      false
    end
  end

  def get_error_data(error_data, media, url, id = nil)
    data = media.nil? ? Media.minimal_data(OpenStruct.new(url: url)) : media.data
    code = error_data[:code]
    error_data[:code] = Lapis::ErrorCodes::const_get(code)
    data.merge(error: error_data)
  end

  def get_timeout_data(media, url, id)
    get_error_data({ message: 'Timeout', code: 'TIMEOUT' }, media, url, id)
  end

  def clean_json(data)
    data.each do |field, value|
      data[field] = cleanup_text(value, field)
    end
  end

  def cleanup_text(content, field = nil)
    if content.is_a?(String)
      content = content.encode("UTF-8", :invalid => :replace, :undef => :replace, :replace => "�".freeze)
      begin
        return RequestHelper.encode_url(content) if field == 'raw' && is_url?(content)
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
    id = Media.cache_key(self.url)
    updates = {}
    [:author_picture, :picture].each do |attr|
      img_url = self.data.dig(attr)
      next if img_url.blank?

      parsed_url = RequestHelper.parse_nonmandatory_url(img_url)
      next if parsed_url.nil?

      if upload_image(id, attr, parsed_url)
        updates[attr] = self.data[attr]
      end
    end
    Media.update_cache(self.url, updates) unless updates.empty?
  end

  def upload_image(id, attr, url)
    extension = File.extname(url.path)
    extension = '.jpg' if extension.blank? || extension == '.php'
    filename = "#{id}/#{attr}#{extension}"
    begin
      URI(url).open do |content|
        Pender::Store.current.store_object(filename, content, 'medias/')
      end
      self.data[attr] = "#{Pender::Store.current.storage_path('medias')}/#{filename}"
      return true
    rescue StandardError => error
      PenderSentry.notify(
        StandardError.new("Could not get '#{attr}' image"),
        url: self.url,
        img_url: url,
        error: {
          class: error.class,
          message: error.message
        }
      )
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

  def ignore_url?(url)
    ignore_url = false
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
    def self.api_key_settings(key_id)
      key = ApiKey.where(id: key_id).last
      key ? key.settings : {}
    end
  end
end
