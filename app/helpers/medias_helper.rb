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
    tag = media.doc.at_css('script[type="application/ld+json"]')
    unless tag.blank?
      begin
        data = JSON.parse(tag.content)
        data['@context'] == 'http://schema.org' ? add_schema_to_data(media, data, data['@type']) : media.data['raw']['json+ld'] = data
      rescue JSON::ParserError
        Rails.logger.info "Could not parse the JSON-LD content: #{media.url}"
      end
    end
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
    args.each do |i|
      return hash[i] if !hash[i].nil?
    end
    ''
  end

  def get_schema_data(media)
    return if self.doc.nil?
    microdata = Mida::Document.new(self.doc)
    if !microdata.items.empty?
      media.data[:schema] ||= {}.with_indifferent_access
      microdata.items.each do |item|
        type = item.type.match(/^https?:\/\/schema\.org\/(.*)/)
        add_schema_to_data(media, item.to_h, type[1]) if type
      end
    end
  end

  def add_schema_to_data(media, data, type)
    media.data[:schema] ||= {}.with_indifferent_access
    media.data['schema'][type] ||= []
    media.data['schema'][type] << data.with_indifferent_access
  end

  def list_formats
    %w(html js json oembed)
  end

  ##
  # Remove HTML entities from standard text fields

  def cleanup_html_entities(media)
    %w(username title description author_name).each do |field|
      media.data[field] = CGI.unescapeHTML(media.data[field])
    end
  end

end
