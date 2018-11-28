module MediaHtmlPreprocessor
  extend ActiveSupport::Concern

  def preprocess_html(html)
    return html unless include_sharethefacts_js(html)
    find_sharethefacts_links(html)
  end

  def include_sharethefacts_js(html)
    parsed_html = Nokogiri::HTML html
    parsed_html.css("script").select { |s| s.attr('src') && s.attr('src').match('sharethefacts')}.any?
  end

  def find_sharethefacts_links(html)
    link = html.match(/<a href=".*sharethefacts.co\/share\/([0-9a-zA-Z\-]+)".*<\/a>/)
    return html if link.nil?
    uuid = link[1]
    sharethefacts_replace_element(html, link, uuid)
  end

  def sharethefacts_replace_element(html, link, uuid)
    source = "https://dhpikd1t89arn.cloudfront.net/html-#{uuid}.html"
    content = open(source).read
    content = "<div>#{content}</div>"
    html.gsub(link[0], content)
  end
end
