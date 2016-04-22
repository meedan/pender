module MediasHelper
  def embed_url
    javascript_include_tag(@request.original_url.gsub(/medias\.html/, 'medias.js'))
  end
end
