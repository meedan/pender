module MediasHelper
  def embed_url
    src = @request.original_url.sub(/medias([^\?]*)/, 'medias.js')
    "<script src=\"#{src}\" type=\"text/javascript\"></script>".html_safe
  end
end
