class CreateDefaultDirectories < ActiveRecord::Migration[4.2]
  def change
    path = File.join(Rails.root, 'public', 'screenshots')
    FileUtils.mkdir_p(path) unless File.exist?(path)
  end
end
