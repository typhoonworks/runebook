# frozen_string_literal: true

module Runebook
  # Parser and exporter for the .runemd file format.
  #
  # Format specification:
  # - `# Title` - Notebook title (H1)
  # - First ```ruby block before any `## Section` - Setup cell
  # - `## Section` - Section header (H2)
  # - ```ruby blocks after a section header - Ruby cells
  # - Any other text after a section header - Markdown cells
  #
  # Example:
  #   # Notebook Title
  #
  #   ```ruby
  #   gem "faker"
  #   ```
  #
  #   ## Section Name
  #
  #   This is a **markdown** cell.
  #
  #   ```ruby
  #   puts "Hello"
  #   ```
  module Runemd
    TITLE_REGEX = /^#\s+([^\n]+)/.freeze
    SECTION_SPLIT_REGEX = /(?=^##\s+)/m.freeze
    SECTION_HEADER_REGEX = /^##\s+([^\n]+)/.freeze
    CODE_FENCE_REGEX = /^```ruby\s*\n(.*?)^```/m.freeze

    Cell = Data.define(:type, :content)
    Section = Data.define(:title, :cells)
    NotebookData = Data.define(:version, :autosave_interval, :title, :setup_cell, :sections)

    class << self
      # Parse a .runemd string into structured data
      #
      # @param content [String] the raw .runemd file content
      # @return [NotebookData] structured notebook data
      def parse(content)
        content = content.dup.force_encoding("UTF-8")

        # Extract title
        title = "Untitled notebook"
        if (title_match = content.match(TITLE_REGEX))
          title = title_match[1].strip
        end

        # Split content by section headers (using lookahead to keep headers)
        parts = content.split(SECTION_SPLIT_REGEX)

        # First part is the preamble (before any ## Section)
        preamble = parts.shift || ""
        setup_cell = nil

        # Extract setup cell from preamble (first ruby code block)
        if (setup_match = preamble.match(CODE_FENCE_REGEX))
          setup_cell = Cell.new(type: :setup, content: setup_match[1].strip)
        end

        # Parse each section
        sections = parts.map { |section_content| parse_section(section_content) }

        # Ensure at least one section exists
        sections << Section.new(title: "Section", cells: []) if sections.empty?

        NotebookData.new(
          version: 1,
          autosave_interval: 30_000,
          title: title,
          setup_cell: setup_cell,
          sections: sections
        )
      end

      # Export structured data to .runemd format
      #
      # @param data [NotebookData, Hash] structured notebook data
      # @return [String] the .runemd formatted string
      def export(data)
        # Support both NotebookData and Hash input
        if data.is_a?(Hash)
          data = normalize_hash_data(data)
        end

        lines = []

        # Title
        lines << "# #{data.title || 'Untitled notebook'}"
        lines << ""

        # Setup cell
        if data.setup_cell
          lines << "```ruby"
          lines << data.setup_cell.content.to_s.strip
          lines << "```"
          lines << ""
        end

        # Sections and cells
        data.sections.each do |section|
          lines << "## #{section.title}"
          lines << ""

          section.cells.each do |cell|
            case cell.type.to_sym
            when :markdown
              lines << cell.content.to_s.strip
              lines << ""
            when :ruby
              lines << "```ruby"
              lines << cell.content.to_s.strip
              lines << "```"
              lines << ""
            end
          end
        end

        lines.join("\n")
      end

      private

      def parse_section(content)
        # Extract section title
        title = "Section"
        if (header_match = content.match(SECTION_HEADER_REGEX))
          title = header_match[1].strip
          # Remove the section header from content
          content = content.sub(SECTION_HEADER_REGEX, "")
        end

        cells = []
        remaining = content.strip

        while remaining.length > 0
          # Check if we're at a ruby code block
          if remaining.match?(/\A```ruby\s*\n/)
            # Extract the code block
            if (code_match = remaining.match(/\A```ruby\s*\n(.*?)^```/m))
              code = code_match[1].strip
              cells << Cell.new(type: :ruby, content: code)
              remaining = remaining[code_match[0].length..].to_s.strip
            else
              # Unclosed code block - treat rest as markdown
              cells << Cell.new(type: :markdown, content: remaining) unless remaining.empty?
              break
            end
          else
            # Everything until the next code block is markdown
            next_code_block = remaining.index(/^```ruby\s*\n/m)
            if next_code_block
              markdown_content = remaining[0...next_code_block].strip
              cells << Cell.new(type: :markdown, content: markdown_content) unless markdown_content.empty?
              remaining = remaining[next_code_block..].to_s
            else
              # No more code blocks - rest is markdown
              cells << Cell.new(type: :markdown, content: remaining) unless remaining.empty?
              break
            end
          end
        end

        Section.new(title: title, cells: cells)
      end

      def normalize_hash_data(hash)
        hash = hash.transform_keys(&:to_sym)

        setup_cell = if hash[:setup_cell]
          sc = hash[:setup_cell].transform_keys(&:to_sym)
          Cell.new(type: sc[:type]&.to_sym || :setup, content: sc[:content] || "")
        end

        sections = (hash[:sections] || []).map do |section|
          section = section.transform_keys(&:to_sym)
          cells = (section[:cells] || []).map do |cell|
            cell = cell.transform_keys(&:to_sym)
            Cell.new(type: cell[:type]&.to_sym || :ruby, content: cell[:content] || "")
          end
          Section.new(title: section[:title] || "Section", cells: cells)
        end

        NotebookData.new(
          version: hash[:version] || 1,
          autosave_interval: hash[:autosave_interval] || 30_000,
          title: hash[:title] || "Untitled notebook",
          setup_cell: setup_cell,
          sections: sections
        )
      end
    end
  end
end
