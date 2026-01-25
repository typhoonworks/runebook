require "commonmarker"
require "nokogiri"
require "rouge"

module MarkdownHelper
  include ActionView::Helpers::SanitizeHelper
  def markdown_to_html(text)
    markdown = text.to_s

    html = Commonmarker.to_html(markdown)

    html = highlight_code_blocks(html)

    warning = heading_level_warning(text)
    html = warning + html if warning.present?

    sanitize_html(html)
  end

  private

  def highlight_code_blocks(html)
    frag = Nokogiri::HTML::DocumentFragment.parse(html)
    frag.css("pre > code").each do |code|
      classes = code["class"].to_s
      language = classes[/language-([A-Za-z0-9_\-\+]+)/, 1]
      code_text = code.text

      lexer = language ? Rouge::Lexer.find_fancy(language, code_text) : Rouge::Lexers::PlainText
      lexer ||= Rouge::Lexers::PlainText
      formatter = Rouge::Formatters::HTML.new
      highlighted = formatter.format(lexer.lex(code_text))

      code.inner_html = highlighted
      pre = code.parent
      pre["class"] = [ pre["class"], "highlight" ].compact.join(" ")
    end
    frag.to_html
  end

  def sanitize_html(html)
    sanitizer = Rails::Html::SafeListSanitizer.new
    sanitizer.sanitize(html, tags: allowed_tags, attributes: allowed_attributes)
  end

  def allowed_tags
    base = if Rails::Html::SafeListSanitizer.respond_to?(:allowed_tags)
      Rails::Html::SafeListSanitizer.allowed_tags
    else
      %w[a abbr b blockquote br cite code dd dl dt em i li ol p pre q s small strike strong sub sup u ul h3 h4 h5 h6 img]
    end
    (base + %w[div span pre code table thead tbody tr th td]).uniq
  end

  def allowed_attributes
    base = if Rails::Html::SafeListSanitizer.respond_to?(:allowed_attributes)
      Rails::Html::SafeListSanitizer.allowed_attributes
    else
      %w[href title class alt src rel]
    end
    (base + %w[class]).uniq
  end

  def heading_level_warning(text)
    return nil unless text.to_s.match?(/^\s{0,3}(#|##)\s/m)
    %(<div class="text-error text-lg font-medium">warning: heading levels 1 and 2 are reserved for notebook and section names, please use heading 3 and above.</div>)
  end
end
