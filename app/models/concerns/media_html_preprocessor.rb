module MediaHtmlPreprocessor
  extend ActiveSupport::Concern

  def preprocess_html(html)
    find_sharethefacts_links(html)
  end

  def find_sharethefacts_links(html)
    link = html.match(/<a href=.*sharethefacts.co\/share\/(.*)">.*<\/a>/)
    return html if link.nil?
    uuid = link[1]
    sharethefacts_replace_element(html, link, uuid)
  end

  def sharethefacts_replace_element(html, link, uuid)
    source = "https://dhpikd1t89arn.cloudfront.net/html-#{uuid}.html"
    content = open(source).read.force_encoding(::Encoding::UTF_8)
    content = "<div>#{content}</div>"
    html.gsub(link[0], content)
  end
end
