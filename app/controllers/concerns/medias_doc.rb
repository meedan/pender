#encoding: utf-8
# :nocov:
module MediasDoc
  extend ActiveSupport::Concern

  included do
    swagger_controller :medias, 'Medias'

    swagger_api :index do
      summary 'Get the metadata for a given URL'
      notes 'Get parseable data for a given URL, that can be a post or a profile, from different providers'
      param :query, :url, :string, :required, 'URL to be parsed/rendered'
      param :query, :refresh, :integer, :optional, 'Force a refresh from the URL instead of the cache'
      authed = { CONFIG['authorization_header'] => 'test' }
      url = 'https://www.youtube.com/user/MeedanTube'
      response :ok, 'Parsed data', { query: { url: url }, headers: authed }
      response 400, 'URL not provided', { query: { url: nil }, headers: authed }
      response 401, 'Access denied', { query: { url: url } }
      response 408, 'Timeout', { query: { url: url }, headers: authed }
      response 429, 'API limit reached', { query: { url: url }, headers: authed }
      response 409, 'URL already being processed', { query: { url: url }, headers: authed }
    end
  end
end
# :nocov:
