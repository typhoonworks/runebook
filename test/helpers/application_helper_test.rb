require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "project_version returns version with v prefix" do
    result = project_version

    assert_match(/\Av\d+\.\d+\.\d+/, result)
  end

  test "inline_svg returns svg content for existing file" do
    result = inline_svg("icons/file")

    assert result.present?
    assert_includes result, "<svg"
    assert result.html_safe?
  end

  test "inline_svg returns empty string for non-existent file" do
    result = inline_svg("nonexistent/icon")

    assert_equal "", result
    assert result.html_safe?
  end

  test "inline_svg adds class to svg element" do
    result = inline_svg("icons/file", class: "w-4 h-4")

    assert_includes result, 'class="w-4 h-4"'
  end

  test "truncate_path returns original path if within max_length" do
    short_path = "/short/path.rb"

    assert_equal short_path, truncate_path(short_path, max_length: 50)
  end

  test "truncate_path returns empty string for blank path" do
    assert_equal "", truncate_path(nil)
    assert_equal "", truncate_path("")
  end

  test "truncate_path truncates long paths keeping filename" do
    long_path = "/very/long/directory/path/that/exceeds/the/limit/filename.runemd"

    result = truncate_path(long_path, max_length: 50)

    assert result.length < long_path.length
    assert_includes result, "filename.runemd"
  end

  test "truncate_path handles very long filenames" do
    long_filename = "/dir/this_is_a_very_long_filename_that_exceeds_everything.runemd"

    result = truncate_path(long_filename, max_length: 40)

    assert result.length <= 40
    assert result.start_with?("...")
  end
end
