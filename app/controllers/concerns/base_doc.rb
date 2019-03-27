# :nocov:
module BaseDoc
  extend ActiveSupport::Concern

  included do
    swagger_controller '/', 'BaseApi'

    swagger_api :about do
      summary 'Information about this application'
      notes 'Use this method to get the archivers enabled on this application'
      authed = { CONFIG['authorization_header'] => 'test' }
      response :ok, 'Information about the application', { query: {}, headers: authed }
      response 401, 'Access denied', { query: {} }
    end
  end
end
# :nocov:
