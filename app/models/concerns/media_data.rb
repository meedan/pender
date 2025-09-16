class MediaData

  EMPTY_DATA_STRUCTURE =
    {
    # required – value should always be present
    url: "",
    provider: "",
    type: "",
    title: "",
    description: "",
    favicon: "",
    parsed_at: "",
    # non-required – values can be blank
    published_at: "",
    username: "",
    picture: "",
    author_url: "",
    author_picture: "",
    author_name: "",
    screenshot: "",
    external_id: "",
    html: "",
    # required keys – some methods expect them to be present
    raw: {},
    archives: {},
  }.with_indifferent_access.freeze

  def self.empty_structure
    EMPTY_DATA_STRUCTURE.deep_dup
  end

  def self.minimal_data(url)
    MediaData.empty_structure.merge!(MediaData.required_fields(url))
  end

  def self.required_fields(url)
    {
      url: url,
      provider: 'page',
      type: 'item',
      title: url,
      description: url,
      parsed_at: Time.now.to_s,
      favicon: "https://www.google.com/s2/favicons?domain_url=#{url.gsub(/^https?:\/\//, ''.freeze)}"
    }.with_indifferent_access
  end

  def self.minimal_parser_data(type, url)
    provider, type = type.split('_')
    {
      # required – value should always be present
      provider: provider,
      type: type,
      url: url,
      # required keys – some methods expect them to be present
      raw: {}
    }.with_indifferent_access
  end
end
