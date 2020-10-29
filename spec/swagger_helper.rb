# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.swagger_root = Rails.root.join('swagger').to_s

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under swagger_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a swagger_doc tag to the
  # the root example_group in your specs, e.g. describe '...', swagger_doc: 'v2/swagger.json'
  config.swagger_docs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'Pender',
        version: 'v1',
        description: 'A parsing and rendering service'
      },
      components: {
        securitySchemes: {
          api_key: {
            type: :apiKey,
            name: PenderConfig.get('authorization_header') || 'X-Token',
            in: :header
          }
        }
      }
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The swagger_docs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.swagger_format = :yaml

  # Workaround for https://github.com/rswag/rswag/issues/325, see https://github.com/rswag/rswag/pull/302
  config.before(:all) do
    module Rswag
      module Specs
        # Hook SwaggerFormatter class method.
        class SwaggerFormatter < ::RSpec::Core::Formatters::BaseTextFormatter
          ::RSpec::Core::Formatters.register(self, :example_group_finished, :stop)

          def upgrade_content!(mime_list, target_node)
            # Fix examples with the following line change.
            target_node[:content] ||= {}
            schema = target_node[:schema]
            return if mime_list.empty? || schema.nil?

            mime_list.each do |mime_type|
              # Fix examples with the following line change.
              (target_node[:content][mime_type] ||= {}).merge!(schema: schema)
            end
          end

          def stop(_notification = nil)
            @config.swagger_docs.each do |url_path, doc|
              unless doc_version(doc).start_with?('2')
                doc[:paths]&.each_pair do |_k, v|
                  v.each_pair do |_verb, value|
                    is_hash = value.is_a?(Hash)
                    if is_hash && value.dig(:parameters)
                      schema_param = value.dig(:parameters)&.find { |p| (p[:in] == :body || p[:in] == :formData) && p[:schema] }
                      mime_list = value.dig(:consumes)
                      if value && schema_param && mime_list
                        value[:requestBody] = { content: {} } unless value.dig(:requestBody, :content)
                        mime_list.each do |mime|
                          value[:requestBody][:content][mime] = { schema: schema_param[:schema] }
                          # Fix examples with the following line.
                          value[:requestBody][:content][mime].merge!(examples: schema_param[:examples]) if schema_param[:examples]
                        end
                      end

                      value[:parameters].reject! { |p| p[:in] == :body || p[:in] == :formData }
                    end
                    remove_invalid_operation_keys!(value)
                  end
                end
              end

              file_path = File.join(@config.swagger_root, url_path)
              dirname = File.dirname(file_path)
              FileUtils.mkdir_p dirname unless File.exist?(dirname)

              File.open(file_path, 'w') do |file|
                file.write(pretty_generate(doc))
              end

              @output.puts "Swagger doc generated at #{file_path}"
            end
          end
        end
      end
    end
  end
end

# Workaround for https://github.com/rswag/rswag/issues/325, see https://github.com/rswag/rswag/pull/302
RSpec.shared_context 'generate examples' do
  after do |example|
    example.metadata[:response][:content] = {
      'application/json' => {
        example: JSON.parse(response.body, symbolize_names: true)
      }
    }
  end
end
