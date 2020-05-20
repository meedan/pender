module MediaPageItem
  extend ActiveSupport::Concern

  included do
    Media.declare('page_item', [/^.*$/])
  end

  def data_from_page_item
    if self.doc.nil?
      self.doc = self.get_html({ allow_redirections: :all })
      get_metatags(self)
    end
    handle_exceptions(self, StandardError) do
      self.data = self.page_get_data_from_url
      unless self.data[:picture].blank?
        self.data[:picture] = self.add_scheme(self.data[:picture])
      end
      self.data.merge!({
        author_name: get_page_author_name,
        author_picture: self.data[:picture]
      })
      self.check_cookie_absent
    end
    self.check_if_safe
  end

  def check_cookie_absent
    metatag = self.get_html_metadata(self, 'name', { cookie: 'pbContext' })
    self.url = self.original_url if !metatag.empty? && !metatag[:cookie].match(/Cookie Absent/).nil?
  end

  def check_if_safe
    if self.unsafe?
      self.data.merge!(error: { message: 'Unsafe URL', code: LapisConstants::ErrorCodes::const_get('UNSAFE') })
      raise Pender::UnsafeUrl
    end
  end

  def unsafe?
    return nil if CONFIG['google_api_key'].blank?
    unsafe = false
    [self.url, self.data['author_url'], self.data['author_picture'], self.data['picture']].each do |url|
      next if url.blank? || unsafe
      begin
        http = Net::HTTP.new('safebrowsing.googleapis.com', 443)
        http.use_ssl = true
        req = Net::HTTP::Post.new('/v4/threatMatches:find?key=' + CONFIG['google_api_key'], 'Content-Type' => 'application/json')
        req.body = {
          client: {
            clientId: 'pender',
            clientVersion: VERSION
          },
          threatInfo: {
            threatTypes: ['MALWARE', 'SOCIAL_ENGINEERING', 'THREAT_TYPE_UNSPECIFIED', 'UNWANTED_SOFTWARE', 'POTENTIALLY_HARMFUL_APPLICATION'],
            platformTypes: ['ANY_PLATFORM'],
            threatEntryTypes: ['URL'],
            threatEntries: [{ url: url }]
          }
        }.to_json
        res = http.request(req)
        unsafe = JSON.parse(res.body)['matches'].size > 0
      rescue
        unsafe = false
      end
    end
    unsafe
  end

  def page_get_data_from_url
    raise 'Could not parse this media' if self.doc.blank?
    data = self.data
    %w(basic oembed opengraph twitter).each do |meta|
      data.merge!(self.send("get_#{meta}_metadata")) { |_key, v1, v2| v2.blank? ? v1 : v2 }
    end
    data
  end

  def get_twitter_metadata
    metatags = { title: 'twitter:title', picture: 'twitter:image', description: 'twitter:description', username: 'twitter:creator', author_name: 'twitter:site' }
    data = get_html_metadata(self, 'name', metatags).with_indifferent_access
    data.merge!(get_html_metadata(self, 'property', metatags))
    data['author_url'] = twitter_author_url(data['username'])
    data.delete('author_name') if ignore_twitter_metatag(data['author_name'])
    unless data['author_url']
      data.delete('author_url')
      data.delete('username')
    end
    data
  end

  def get_opengraph_metadata
    metatags = { title: 'og:title', picture: 'og:image', description: 'og:description', username: 'article:author', published_at: 'article:published_time', author_name: 'og:site_name' }
    data = get_html_metadata(self, 'property', metatags)
    if (data['username'] =~ /\A#{URI::regexp}\z/)
      data['author_url'] = data['username']
      data.delete('username')
    end
    data['published_at'] = verify_published_time(data['published_at']) unless data['published_at'].blank?
    data
  end

  def get_oembed_metadata
    self.data_from_oembed_item
    self.post_process_oembed_data || {}
  end

  def get_basic_metadata
    metatags = { title: 'title',  description: 'description', username: 'author', author_name: 'application-name' }
    data = get_html_metadata(self, 'name', metatags)
    title = self.doc.at_css("title")
    data[:title] ||= title.nil? ? '' : title.content
    data[:description] ||= ''
    data[:username] ||= ''
    data[:published_at] = ''
    data[:picture] = ''

    data[:author_url] = top_url(self.url)
    data
  end

  def get_page_author_name
    return self.data['author_name'] unless self.data['author_name'].blank?
    self.data['username'].blank? ? self.data['title'] : self.data['username']
  end
end
