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
      param :query, :archivers, :string, :optional, 'List of archivers to target. Can be empty, `none` or a list of archives separated by commas'
      authed = { CONFIG['authorization_header'] => 'test' }
      url = 'https://www.youtube.com/user/MeedanTube'
      response :ok, 'Parsed data', { query: { url: url }, headers: authed }
      response 400, 'URL not provided', { query: { url: nil }, headers: authed }
      response 401, 'Access denied', { query: { url: url } }
      response 408, 'Timeout', { query: { url: url }, headers: authed }
      response 429, 'API limit reached', { query: { url: url }, headers: authed }
      response 409, 'URL already being processed', { query: { url: url }, headers: authed }
    end

    swagger_api :bulk do
      summary 'Get the metadata of a list of URLs and archive it'
      notes 'Create background jobs to parse each URL and notify the caller with the result'
      param :query, :url, :string, :required, 'URL(s) to be parsed. Can be an array of URLs, a single URL or a list of URLs separated by a commas
'
      param :query, :refresh, :integer, :optional, 'Force a refresh from the URL instead of the cache. Will be applied to all URLs'
      param :query, :archivers, :string, :optional, 'List of archivers to target. Can be empty, `none` or a list of archives separated by commas. Will be applied to all URLs'
      authed = { CONFIG['authorization_header'] => 'test' }
      url1 = 'https://www.youtube.com/user/MeedanTube'
      url2 = 'https://twitter.com/meedan'
      response :ok, 'Enqueued URLs', { query: { url: [url1, url2] }, headers: authed }
      response 401, 'Access denied', { query: { url: [url1, url2] } }
    end
  end
end
# :nocov:
