module MediasHelper
  def embed_url
    src = convert_url_to_format(@request.original_url, 'js')
    "<script src=\"#{src}\" type=\"text/javascript\"></script>".html_safe
  end

  def convert_url_to_format(url, format)
    url = url.sub(/medias([^\?]*)/, 'medias.' + format)
    if url =~ /refresh=1/
      url = url.sub(/refresh=1/, '').sub(/medias\.#{format}\?/, "medias.#{format}?refresh=1&").sub(/\&$/, '')
    end
    url
  end
end
