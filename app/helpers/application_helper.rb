module ApplicationHelper
  def project_version
    "v#{Runebook::VERSION}"
  end

  def inline_svg(filename, options = {})
    file_path = Rails.root.join("public", "#{filename}.svg")
    return "".html_safe unless File.exist?(file_path)

    svg = File.read(file_path)

    if options[:class].present?
      # Replace existing class attribute or add one to the opening svg tag
      if svg.include?("class=")
        svg = svg.sub(/<svg([^>]*)class="[^"]*"/, %(<svg\\1class="#{options[:class]}"))
      else
        svg = svg.sub(/<svg/, %(<svg class="#{options[:class]}"))
      end
    end

    svg.html_safe
  end

  def truncate_path(path, max_length: 40)
    return "" if path.blank?
    return path if path.length <= max_length

    dirname = File.dirname(path)
    basename = File.basename(path)

    return "...#{basename[-(max_length - 3)..]}" if basename.length >= max_length - 3

    # Calculate available space for directory
    available = max_length - basename.length - 4 # 4 for "/..." separator
    return "...#{basename}" if available <= 0

    "#{dirname[0, available]}/.../#{basename}"
  end
end
