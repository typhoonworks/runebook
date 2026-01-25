# frozen_string_literal: true

require "test_helper"
require "runebook/runemd"

class Runebook::RunemdTest < ActiveSupport::TestCase
  test "parse extracts title" do
    content = <<~RUNEMD
      # My Awesome Notebook

      ## Section

    RUNEMD

    data = Runebook::Runemd.parse(content)

    assert_equal "My Awesome Notebook", data.title
  end

  test "parse uses default title when missing" do
    content = <<~RUNEMD
      ## Section

    RUNEMD

    data = Runebook::Runemd.parse(content)

    assert_equal "Untitled notebook", data.title
  end

  test "parse extracts setup cell from preamble" do
    content = <<~RUNEMD
      # Test Notebook

      ```ruby
      gem "faker"
      gem "rails"
      ```

      ## Section

    RUNEMD

    data = Runebook::Runemd.parse(content)

    assert_not_nil data.setup_cell
    assert_equal :setup, data.setup_cell.type
    assert_equal "gem \"faker\"\ngem \"rails\"", data.setup_cell.content
  end

  test "parse returns nil setup_cell when no ruby block in preamble" do
    content = <<~RUNEMD
      # Test Notebook

      ## Section

      ```ruby
      puts "hello"
      ```

    RUNEMD

    data = Runebook::Runemd.parse(content)

    assert_nil data.setup_cell
  end

  test "parse only uses first ruby block in preamble as setup" do
    content = <<~RUNEMD
      # Test Notebook

      ```ruby
      gem "faker"
      ```

      ```ruby
      gem "ignored"
      ```

      ## Section

    RUNEMD

    data = Runebook::Runemd.parse(content)

    assert_not_nil data.setup_cell
    assert_equal "gem \"faker\"", data.setup_cell.content
  end

  test "parse extracts ruby cells from sections" do
    content = <<~RUNEMD
      # Test Notebook

      ## Section

      ```ruby
      puts "Hello, World!"
      ```

    RUNEMD

    data = Runebook::Runemd.parse(content)

    assert_equal 1, data.sections.size
    assert_equal 1, data.sections.first.cells.size
    assert_equal :ruby, data.sections.first.cells.first.type
    assert_equal 'puts "Hello, World!"', data.sections.first.cells.first.content
  end

  test "parse extracts markdown cells from sections" do
    content = <<~RUNEMD
      # Test Notebook

      ## Section

      This is **bold** and *italic* text.

    RUNEMD

    data = Runebook::Runemd.parse(content)

    assert_equal 1, data.sections.size
    assert_equal 1, data.sections.first.cells.size
    assert_equal :markdown, data.sections.first.cells.first.type
    assert_equal "This is **bold** and *italic* text.", data.sections.first.cells.first.content
  end

  test "parse handles multiple sections" do
    content = <<~RUNEMD
      # Test Notebook

      ## First Section

      ```ruby
      puts "First"
      ```

      ## Second Section

      ```ruby
      puts "Second"
      ```

    RUNEMD

    data = Runebook::Runemd.parse(content)

    assert_equal 2, data.sections.size
    assert_equal "First Section", data.sections[0].title
    assert_equal "Second Section", data.sections[1].title
    assert_equal 'puts "First"', data.sections[0].cells.first.content
    assert_equal 'puts "Second"', data.sections[1].cells.first.content
  end

  test "parse handles mixed cell types in a section" do
    content = <<~RUNEMD
      # Mixed Notebook

      ## Main Section

      Introduction text here.

      ```ruby
      x = 1 + 2
      ```

      Conclusion text here.

    RUNEMD

    data = Runebook::Runemd.parse(content)

    section = data.sections.first
    assert_equal 3, section.cells.size
    assert_equal :markdown, section.cells[0].type
    assert_equal "Introduction text here.", section.cells[0].content
    assert_equal :ruby, section.cells[1].type
    assert_equal "x = 1 + 2", section.cells[1].content
    assert_equal :markdown, section.cells[2].type
    assert_equal "Conclusion text here.", section.cells[2].content
  end

  test "parse treats other language code blocks as markdown" do
    content = <<~RUNEMD
      # Test Notebook

      ## Section

      Here is some JSON:

      ```json
      {"key": "value"}
      ```

      And more text.

    RUNEMD

    data = Runebook::Runemd.parse(content)

    # JSON block should be part of markdown content
    assert_equal 1, data.sections.size
    cells = data.sections.first.cells
    assert_equal 1, cells.size
    assert_equal :markdown, cells.first.type
    assert_includes cells.first.content, "```json"
  end

  test "export generates simplified runemd format" do
    data = Runebook::Runemd::NotebookData.new(
      version: 1,
      autosave_interval: 30_000,
      title: "My Notebook",
      setup_cell: Runebook::Runemd::Cell.new(type: :setup, content: 'gem "faker"'),
      sections: [
        Runebook::Runemd::Section.new(
          title: "Section One",
          cells: [
            Runebook::Runemd::Cell.new(type: :markdown, content: "Hello **world**"),
            Runebook::Runemd::Cell.new(type: :ruby, content: "puts 'hi'")
          ]
        )
      ]
    )

    output = Runebook::Runemd.export(data)

    assert_includes output, "# My Notebook"
    assert_includes output, "```ruby\ngem \"faker\"\n```"
    assert_includes output, "## Section One"
    assert_includes output, "Hello **world**"
    assert_includes output, "```ruby\nputs 'hi'\n```"
    # Should NOT contain HTML comment markers
    refute_includes output, "<!-- runemd"
  end

  test "export accepts hash input" do
    data = {
      version: 1,
      autosave_interval: 30_000,
      title: "Hash Notebook",
      setup_cell: { type: "setup", content: 'require "json"' },
      sections: [
        {
          title: "Main",
          cells: [
            { type: "ruby", content: "puts 1 + 2" }
          ]
        }
      ]
    }

    output = Runebook::Runemd.export(data)

    assert_includes output, "# Hash Notebook"
    assert_includes output, "```ruby\nrequire \"json\"\n```"
    assert_includes output, "## Main"
    assert_includes output, "puts 1 + 2"
  end

  test "roundtrip parse and export preserves data" do
    original = <<~RUNEMD
      # Roundtrip Test

      ```ruby
      gem "test"
      ```

      ## Section

      Some text here.

      ```ruby
      x = 42
      ```

    RUNEMD

    data = Runebook::Runemd.parse(original)
    exported = Runebook::Runemd.export(data)
    reparsed = Runebook::Runemd.parse(exported)

    assert_equal data.title, reparsed.title
    assert_equal data.setup_cell.content, reparsed.setup_cell.content
    assert_equal data.sections.first.title, reparsed.sections.first.title
    assert_equal data.sections.first.cells.size, reparsed.sections.first.cells.size

    data.sections.first.cells.each_with_index do |cell, i|
      assert_equal cell.type, reparsed.sections.first.cells[i].type
      assert_equal cell.content, reparsed.sections.first.cells[i].content
    end
  end

  test "parse handles empty content gracefully" do
    content = ""

    data = Runebook::Runemd.parse(content)

    assert_equal 1, data.version
    assert_equal "Untitled notebook", data.title
    assert_nil data.setup_cell
    assert_equal 1, data.sections.size
  end

  test "parse ignores text before first section that is not setup" do
    content = <<~RUNEMD
      # Test Notebook

      Some random text that should be ignored.

      ## Section

      ```ruby
      puts "hello"
      ```

    RUNEMD

    data = Runebook::Runemd.parse(content)

    # No setup cell since there's no ruby block in preamble
    assert_nil data.setup_cell
    # Section should have the ruby cell
    assert_equal 1, data.sections.size
    assert_equal 'puts "hello"', data.sections.first.cells.first.content
  end

  test "parse handles section with no cells" do
    content = <<~RUNEMD
      # Test Notebook

      ## Empty Section

      ## Section With Content

      ```ruby
      puts "hello"
      ```

    RUNEMD

    data = Runebook::Runemd.parse(content)

    assert_equal 2, data.sections.size
    assert_equal "Empty Section", data.sections[0].title
    assert_equal 0, data.sections[0].cells.size
    assert_equal "Section With Content", data.sections[1].title
    assert_equal 1, data.sections[1].cells.size
  end

  test "export without setup cell" do
    data = Runebook::Runemd::NotebookData.new(
      version: 1,
      autosave_interval: 30_000,
      title: "No Setup",
      setup_cell: nil,
      sections: [
        Runebook::Runemd::Section.new(
          title: "Section",
          cells: [
            Runebook::Runemd::Cell.new(type: :ruby, content: "puts 'hi'")
          ]
        )
      ]
    )

    output = Runebook::Runemd.export(data)

    # Should have title followed directly by section
    lines = output.lines.map(&:chomp)
    title_index = lines.index("# No Setup")
    section_index = lines.index("## Section")

    # No setup block between title and section (just empty line)
    assert title_index < section_index
    assert_equal "", lines[title_index + 1]
    assert_equal "## Section", lines[title_index + 2]
  end

  test "parse uses default version and autosave_interval" do
    content = <<~RUNEMD
      # Test Notebook

      ## Section

    RUNEMD

    data = Runebook::Runemd.parse(content)

    assert_equal 1, data.version
    assert_equal 30_000, data.autosave_interval
  end
end
