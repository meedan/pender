#encoding: utf-8 
# :nocov:
module MediasDoc
  extend ActiveSupport::Concern
 
  included do
    swagger_controller :medias, 'Medias'

    swagger_api :index do
      summary 'Get the metadata for a given URL'
      notes 'Getparseable data for a given URL, that can be a post or a profile, from different providers'
      param :query, :url, :string, :required, 'URL to be parsed/rendered'
      authed = { CONFIG['authorization_header'] => 'test' }
      response :ok, 'Parsed data', { query: { url: 'http://meedan.com' }, headers: authed }
      response 400, 'URL not provided', { query: { url: nil }, headers: authed }
      response 401, 'Access denied', { query: { url: 'http://meedan.com' } }
    end
  end
end
# :nocov:
