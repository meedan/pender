module MediasHelper
  def embed_url(request = @request)
    src = convert_url_to_format(request.original_url, 'js')
    "<script src=\"#{src}\" type=\"text/javascript\"></script>".html_safe
  end

  def convert_url_to_format(url, format)
    url = url.sub(/medias([^\?]*)/, 'medias.' + format)
    if url =~ /refresh=1/
      url = url.sub(/refresh=1/, '').sub(/medias\.#{format}\?/, "medias.#{format}?refresh=1&").sub(/\&$/, '')
    end
    url
  end

  def timeout_value
    CONFIG['timeout'] || 20
  end

  def handle_exceptions(media, exception, message_method = :message, code_method = :code)
    begin
      yield
    rescue exception => error
      Airbrake.notify(error, url: media.url, data: media.data ) if Airbrake.configured?
      code = error.respond_to?(code_method) ? error.send(code_method) : 5
      media.data.merge!(error: { message: "#{error.class}: #{error.send(message_method)}", code: code })
      return
    end
  end

  def get_metatags(media)
    fields = []
    unless media.doc.nil?
      media.doc.search('meta').each do |meta|
        metatag = {}
        meta.each do |key, value|
          metatag.merge!({key => value.strip}) unless value.blank?
        end
        fields << metatag
      end
    end
    media.data['raw']['metatags'] = fields
  end

  def get_jsonld_data(media)
    return if media.doc.nil?
    data = jsonld_tag_content(media)
    if data
      (data.is_a?(Hash) && data.dig('@context')) == 'http://schema.org' ? add_schema_to_data(media, data, data.dig('@type')) : media.data['raw']['json+ld'] = data
    end
  end

  def jsonld_tag_content(media)
    tag = media.doc.at_css('script[type="application/ld+json"]')
    return if tag.blank? || tag.content == 'null'
    begin
      data = JSON.parse(tag.content)
      data = data[0] if data.is_a?(Array)
    rescue JSON::ParserError
      Rails.logger.info "Could not parse the JSON-LD content: #{media.url}"
    end
    data
  end

  def get_html_metadata(media, attr, metatags)
    data = {}.with_indifferent_access
    metatags.each do |key, value|
      metatag = media.data['raw']['metatags'].find { |tag| tag[attr] == value }
      data[key] = metatag['content'] if metatag
    end
    data
  end

  def get_info_from_data(source, data, *args)
    hash = data['raw'][source]
    return '' if hash.nil?
    args.each do |i|
      return hash[i] if !hash[i].nil?
    end
    ''
  end

  def list_formats
    %w(html js json oembed)
  end

  ##
  # Remove HTML entities from standard text fields

  def cleanup_html_entities(media)
    %w(username title description author_name).each do |field|
      media.data[field] = HTMLEntities.new.decode(media.data[field])
    end
  end

  def decoded_uri(url)
    URI.decode(url)
  end

  def verify_published_time(time1, time2 = nil)
    begin
      Time.parse(time1)
    rescue ArgumentError
      time2.nil? ? Time.at(time1.to_i) : Time.at(time2.to_i)
    end
  end

  def is_url?(url)
    uri = URI.parse(URI.encode(url))
    !uri.host.nil? && uri.userinfo.nil?
  end

  def get_error_data(error_data, media, url, id)
    data = media.nil? ? Media.minimal_data(OpenStruct.new(url: url)) : media.data
    data = data.merge(error: error_data)
    Pender::Store.write(id, :json, data)
    data
  end

  def get_timeout_data(media, url, id)
    get_error_data({ message: 'Timeout', code: 'TIMEOUT' }, media, url, id)
  end
end
