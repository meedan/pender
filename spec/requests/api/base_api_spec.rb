require 'swagger_helper'

include SampleData
auth_header = PenderConfig.get('authorization_header') || 'X-Token'
authed = create_api_key.access_token

RSpec.describe 'BaseApi', type: :request do

  path '/api/about' do

    get 'Information about this application' do
      tags 'base_api'
      description 'Use this method to get the archivers enabled on this application'
      produces 'application/json'
      security [ api_key: {} ]

      response '200', 'Information about the application' do
        schema type: :object,
          properties: {
            type: { type: :string },
            data: {
              type: :object,
              properties: {
                name: { type: :string },
                version: { type: :string },
                archivers: {
                  type: :array,
                  items: {
                    type: :object,
                    properties: {
                      key: { type: :string },
                      label: { type: :string }
                    },
                    required: [ 'key', 'label' ]
                  }
                }
              },
              required: [ 'name', 'version', 'archivers' ]
            }
          },
          required: [ 'type', 'data' ]

        let(auth_header) { authed }
        run_test! do |response|
          response_body = JSON.parse(response.body)
          expect(response_body).not_to be_nil
          expect(response_body['type']).to eq('about')
          data = response_body['data']
          expect(data).not_to be_nil
          expect(data['name']).to eq('Keep')
          expect(data['version']).to eq(VERSION)
          expect(data['archivers']).to eq([{"key"=>"archive_org", "label"=>"Archive.org"}, {"key"=>"perma_cc", "label"=>"Perma.cc"}, {"key"=>"video", "label"=>"Video"}])
        end

        include_context 'generate examples'
      end

      response '401', 'Access denied' do
        schema type: :object,
          properties: {
            type: { type: :string },
            data: {
              type: :object,
              properties: {
                message: { type: :string },
                code: { type: :integer }
              },
              required: [ 'message', 'code' ]
            }
          },
          required: [ 'type', 'data' ]

        let(auth_header) { nil }
        run_test!

        include_context 'generate examples'
      end
    end
  end
end
