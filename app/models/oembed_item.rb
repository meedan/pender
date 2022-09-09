require 'error_codes'

class OembedItem
  def initialize(oembed_url)
    @oembed_url = oembed_url
    @data = {}.with_indifferent_access
  end

  def get_data
    return {} if oembed_url.blank?

    handle_exceptions(StandardError) do
      response = get_oembed_data_from_url(oembed_url)
      @data.merge!(parse_oembed_response(response))
    end
    data
  end

  private

  attr_reader :oembed_url, :data

  def get_oembed_data_from_url(url)
    response = nil
    uri = URI.parse(RequestHelper.absolute_url(url))
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'

    headers = { 'User-Agent' => 'Mozilla/5.0 (compatible; Pender/0.1; +https://github.com/meedan/pender)' }.merge(RequestHelper.get_cf_credentials(uri))
    request = Net::HTTP::Get.new(uri.request_uri, headers)
    response = http.request(request)

    if %w(301 302).include?(response.code)
      response = get_oembed_data_from_url(response.header['location'])
    end
    response
  end

  def parse_oembed_response(response)
    return if response.nil? || response.body.blank?

    oembed_json = JSON.parse(response.body)
    if oembed_json['html'].present?
      doc = Nokogiri::HTML oembed_json['html']
      # Discard the oEmbed's HTML fragment in the following cases:
      # - The script.src URL is not HTTPS
      # - The iframe.src response includes X-Frame-Options = DENY or SAMEORIGIN
      oembed_json['html'] = '' if invalid_html_script?(doc)
      oembed_json['html'] = '' if invalid_html_iframe?(doc)
    end
    oembed_json
  end

  def invalid_html_script?(doc)
    script_tag = doc.at_css('script')
    return if script_tag.nil? || script_tag.attr('src').nil?

    uri = URI.parse(script_tag.attr('src'))
    !uri.kind_of?(URI::HTTPS)
  end

  def invalid_html_iframe?(doc)
    iframe_tag = doc.at_css('iframe')
    return if iframe_tag.nil? || iframe_tag.attr('src').nil?

    uri = URI.parse(iframe_tag.attr('src'))
    return if uri.hostname.match(/^(www\.)?youtube\.com/)
    
    response = Net::HTTP.get_response(uri)
    response&.code&.to_s == '200' && ['DENY', 'SAMEORIGIN'].include?(response.header['X-Frame-Options'])
  end

  def handle_exceptions(exception)
    begin
      yield
    rescue exception => error
      PenderAirbrake.notify(error, oembed_url: oembed_url, oembed_data: data )
      code = error.is_a?(JSON::ParserError) ? LapisConstants::ErrorCodes::const_get('INVALID_VALUE') : LapisConstants::ErrorCodes::const_get('UNKNOWN')
      @data.merge!(error: { message: "#{error.class}: #{error.message}", code: code })
      Rails.logger.warn level: 'WARN', message: '[Parser] Could not parse oembed data', oembed_url: oembed_url, code: code, error_class: error.class, error_message: error.message
      return
    end
  end
end

