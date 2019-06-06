module Pender
  class Store

    def self.store_path(id, type)
      dir = File.join('public', "cache#{ENV['TEST_ENV_NUMBER']}", Rails.env)
      FileUtils.mkdir_p(dir) unless File.exist?(dir)
      File.join(dir, "#{id}.#{type}")
    end

    def self.exist?(id, type)
      File.exist?(store_path(id, type))
    end

    def self.read(id, type)
      path = store_path(id, type)
      File.exist?(path) ? load_file(type, path) : nil
    end

    def self.load_file(type, path)
      file = File.read(path)
      type == :json ? JSON.parse(file).with_indifferent_access : file
    end

    def self.write(id, type, content)
      content = JSON.pretty_generate(content) if type == :json
      File.atomic_write(store_path(id, type)) { |file| file.write(content) }
    end

    def self.delete(id, *types)
      types.each do |type|
        FileUtils.rm_f(store_path(id, type))
      end
    end
  end
end
