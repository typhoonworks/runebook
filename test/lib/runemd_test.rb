require "test_helper"
require "runebook/runemd"

class RunemdParserTest < ActiveSupport::TestCase
  FIXTURE_PATH = Rails.root.join("test", "fixtures", "files", "hello_world.runemd")

  test "parses title, setup, section and ruby cell" do
    sample = File.read(FIXTURE_PATH)
    data = Runebook::Runemd.parse(sample)

    assert_equal 1, data.version
    assert_equal 30_000, data.autosave_interval
    assert_equal "Hello World!", data.title

    assert data.setup_cell, "expected setup cell"
    assert_equal :setup, data.setup_cell.type
    expected_setup = [
      "# Install gems for this notebook",
      "# Example:",
      "# gem \"faker\", \"~> 3.0\"",
      "# gem \"httparty\""
    ].join("\n")
    assert_equal expected_setup, data.setup_cell.content

    assert_equal 1, data.sections.size
    sec = data.sections.first
    assert_equal "Section", sec.title
    assert_equal 1, sec.cells.size
    cell = sec.cells.first
    assert_equal :ruby, cell.type
    assert_equal "puts \"hello world!\"", cell.content
  end
end
