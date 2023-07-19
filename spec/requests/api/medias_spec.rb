require 'swagger_helper'

include SampleData
auth_header = PenderConfig.get('authorization_header') || 'X-Token'
authed = create_api_key.access_token

RSpec.describe 'Medias', type: :request do

  path '/api/medias' do

    get 'Get the metadata for a given URL' do
      tags 'medias'
      description 'Get parseable data for a given URL, that can be a post or a profile, from different providers'
      produces 'application/json', 'text/html'
      parameter name: :url, in: :query, type: :string, required: true, description: 'URL to be parsed/rendered'
      parameter name: :refresh, in: :query, type: :integer, required: false, description: 'Force a refresh from the URL instead of the cache'
      parameter name: :archivers, in: :query, type: :string, required: false, description: 'List of archivers to target. Can be empty, `none` or a list of archives separated by commas'
      security [ api_key: {} ]

      response '200', 'Parsed data' do
        schema type: :object,
          properties: {
            type: { type: :string },
            data: {
              type: :object,
              properties: {
                parsed_at: { type: :string },
                error: {
                  type: :object,
                  properties: {
                    message: { type: :string },
                    code: { type: :integer }
                  },
                  required: [ 'message', 'code' ]
                },
                provider: { type: :string },
                type: { type: :string },
                embed_tag: { type: :string },
                title: { type: :string }
              },
              required: [ 'provider', 'type', 'embed_tag' ]
            }
          },
          required: [ 'type', 'data' ]

        let(:url) { 'https://www.youtube.com/user/MeedanTube' }
        let(auth_header) { authed }
        run_test!

        include_context 'generate examples'
      end

      response '400', 'URL not provided' do
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

        let(:url) { nil }
        let(auth_header) { authed }
        run_test!

        include_context 'generate examples'
      end

      response '400', 'Invalid URL', document: false do
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

        let(:url) { 'not-valid' }
        let(auth_header) { authed }

        run_test! do |response|
          response_body = JSON.parse(response.body)
          expect(response_body).not_to be_nil
          data = response_body['data']
          expect(data['message']).to eq('The URL is not valid')
        end

        include_context 'generate examples'
      end

      response '400', 'URL not found', document: false do
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

        let(:url) { 'http://not-valid' }
        let(auth_header) { authed }

        run_test! do |response|
          response_body = JSON.parse(response.body)
          expect(response_body).not_to be_nil
          data = response_body['data']
          expect(data['message']).to match(/The URL is not valid/)
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

        let(:url) { 'http://meedan.com' }
        let(auth_header) { nil }
        run_test!

        include_context 'generate examples'
      end

      response '408', 'Timeout' do
        let(:url) { 'https://www.youtube.com/user/MeedanTube' }
        let(auth_header) { authed }

        before do |example|
          submit_request(example.metadata)
        end

        # Document without validating response
        it 'returns a 408 response' do
        end
      end

      response '429', 'API limit reached' do
        schema type: :object,
          properties: {
            type: { type: :string },
            data: {
              type: :object,
              properties: {
                message: { type: :integer },
                code: { type: :integer }
              },
              required: [ 'message', 'code' ]
            }
          },
          required: [ 'type', 'data' ]

        let(:url) { 'https://twitter.com/anxiaostudio' }
        let(auth_header) { authed }

        before do |example|
          allow_any_instance_of(Twitter::REST::Client).to receive(:user).and_raise(Twitter::Error::TooManyRequests)
          allow_any_instance_of(Twitter::Error::TooManyRequests).to receive(:rate_limit).and_return(OpenStruct.new(reset_in: 123))

          submit_request(example.metadata)
        end

        it 'should return API limit reached error' do |example|
          pending("twitter api key is not currently working")
          assert_response_matches_metadata(example.metadata)

          response_body = JSON.parse(response.body)
          expect(response_body).not_to be_nil
          data = response_body['data']
          expect(data['message']).to eq(123)
        end

        after do
          allow_any_instance_of(Twitter::REST::Client).to receive(:user).and_call_original
          allow_any_instance_of(Twitter::Error::TooManyRequests).to receive(:rate_limit).and_call_original
        end

        include_context 'generate examples'
      end

      response '409', 'URL already being processed' do
        let(:url) { 'https://www.youtube.com/user/MeedanTube' }
        let(auth_header) { authed }

        before do |example|
          submit_request(example.metadata)
        end

        # Document without validating response
        it 'returns a 409 response' do
        end
      end
    end

    delete 'Delete cache for given URL(s)' do
      tags 'medias'
      description 'Delete cache for the URL(s) passed as parameter, you can use the HTTP verbs DELETE or PURGE'
      produces 'application/json'
      parameter name: :url, in: :query, type: :string, required: true, description: 'URL(s) whose cache should be delete... can be an array of URLs, a single URL or a list of URLs separated by a space'
      security [ api_key: {} ]

      response '200', 'Success' do
        schema type: :object,
          properties: {
            type: { type: :string }
          },
          required: [ 'type' ]

        let(:url) { 'https://www.youtube.com/user/MeedanTube' }
        let(auth_header) { authed }
        run_test!

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

        let(:url) { 'http://test.com' }
        let(auth_header) { nil }
        run_test!

        include_context 'generate examples'
      end
    end

    post 'Get the metadata of a list of URLs and archive it' do
      tags 'medias'
      description 'Create background jobs to parse each URL and notify the caller with the result'
      produces 'application/json'
      parameter name: :url, in: :query, required: true, description: 'URL(s) to be parsed. Can be an array of URLs, a single URL or a list of URLs separated by commas', schema: {
        type: :array,
        items: {
          type: :string
        }
      }
      parameter name: :refresh, in: :query, type: :integer, required: false, description: 'Force a refresh from the URL instead of the cache. Will be applied to all URLs'
      parameter name: :archivers, in: :query, type: :string, required: false, description: 'List of archivers to target. Can be empty, `none` or a list of archives separated by commas. Will be applied to all URLs'
      security [ api_key: {} ]

      response '200', 'Enqueued URLs' do
        schema type: :object,
          properties: {
            type: { type: :string },
            data: {
              type: :object,
              properties: {
                enqueued: {
                  type: :array,
                  items: {
                    type: :string
                  }
                },
                failed: {
                  type: :array,
                  items: {
                    type: :string
                  }
                }
              },
              required: [ 'enqueued', 'failed' ]
            }
          },
          required: [ 'type', 'data' ]

        let(:url) { ['https://www.youtube.com/user/MeedanTube', 'https://twitter.com/meedan'] }
        let(auth_header) { authed }
        run_test!

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

        let(:url) { ['https://www.youtube.com/user/MeedanTube', 'https://twitter.com/meedan'] }
        let(auth_header) { nil }
        run_test!

        include_context 'generate examples'
      end
    end
  end
end
