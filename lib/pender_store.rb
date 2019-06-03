module Pender
  class Store

    def initialize(id)
      raise ArgumentError.new('[Pender Store] Id must be present') unless id
      @id = id
    end

    def store_path(type)
      dir = File.join('public', "cache#{ENV['TEST_ENV_NUMBER']}", Rails.env)
      FileUtils.mkdir_p(dir) unless File.exist?(dir)
      File.join(dir, "#{@id}.#{type}")
    end

    def exist?(type)
      File.exist?(store_path(type))
    end

    def read(type)
      path = store_path(type)
      File.exist?(path) ? load_file(type, path) : nil
    end

    def load_file(type, path)
      file = File.read(path)
      type == :json ? JSON.parse(file).with_indifferent_access : file
    end

    def write(type, content)
      content = JSON.pretty_generate(content) if type == :json
      File.atomic_write(store_path(type)) { |file| file.write(content) }
    end

    def delete(type)
      FileUtils.rm_f(store_path(type))
    end
  end
end
