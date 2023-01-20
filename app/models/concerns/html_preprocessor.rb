module HtmlPreprocessor
  class << self
    def preprocess_html(html)
      html = find_sharethefacts_links(html) if include_sharethefacts_js(html)
      unless html.blank?
        html.gsub!('<!-- <div', '<div')
        html.gsub!('div> -->', 'div>')
      end
      html
    end

    private

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
      content = URI.open("https://dhpikd1t89arn.cloudfront.net/html-#{uuid}.html").read
      content = "<div>#{content}</div>"
      html.gsub(link[0], content)
    end
  end
end
