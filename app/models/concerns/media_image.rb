class MediaImage
  attr_reader :media, :attribute

  def initialize(media, attribute)
    @media = media
    @attribute = attribute
    @media_id = Media.get_id(@media.url)
    @url = media.data.dig(attribute)
    @parsed_url = RequestHelper.parse_nonmandatory_url(@url)
  end

  def upload
    return false if @parsed_url.blank?

    begin
      URI(@parsed_url).open do |content|
        Pender::Store.current.store_object(filename, content, 'medias/')
      end

      media.data[attribute] = storage_path
      Media.update_cache(media.url, { attribute => media.data[attribute] })
      true
    rescue StandardError => error
      report_failure(error)
      false
    end
  end

  private

  def extension
    ext = File.extname(@parsed_url.path)
    ext.blank? || ext == '.php' ? '.jpg' : ext
  end

  def filename
    "#{@media_id}/#{attribute}#{extension}"
  end

  def storage_path
    "#{Pender::Store.current.storage_path('medias')}/#{filename}"
  end

  def report_failure(error)
    PenderSentry.notify(
      StandardError.new("Could not get '#{attribute}' image"),
      url: media.url,
      img_url: @parsed_url,
      error: {
        class: error.class,
        message: error.message
      }
    )
    Rails.logger.warn level: 'WARN',
                      message: "[Parser] Could not get '#{attribute}' image",
                      url: media.url,
                      img_url: @parsed_url,
                      error_class: error.class,
                      error_message: error.message
    false
  end
end
