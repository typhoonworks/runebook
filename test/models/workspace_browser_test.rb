require "test_helper"

class WorkspaceBrowserTest < ActiveSupport::TestCase
  setup do
    @workspace = Rails.root.join("tmp", "test_workspace_#{SecureRandom.hex(4)}")
    FileUtils.mkdir_p(@workspace)
    FileUtils.mkdir_p(@workspace.join("subdir"))
    FileUtils.mkdir_p(@workspace.join(".hidden"))
    File.write(@workspace.join("notebook.runemd"), "# Test")
    File.write(@workspace.join("other.txt"), "text")
    File.write(@workspace.join(".hidden_file.runemd"), "hidden")

    @browser = WorkspaceBrowser.new(workspace_dir: @workspace)
  end

  teardown do
    FileUtils.rm_rf(@workspace) if @workspace&.exist?
  end

  test "browse returns entries for workspace root" do
    result = @browser.browse

    assert result.success?
    assert_equal @workspace.to_s, result.current_path
    assert_nil result.parent_path
    assert_equal @workspace.to_s, result.workspace_root
  end

  test "browse lists directories before files" do
    result = @browser.browse

    entries = result.entries
    dir_index = entries.find_index { |e| e.name == "subdir" }
    file_index = entries.find_index { |e| e.name == "notebook.runemd" }

    assert dir_index < file_index
  end

  test "browse only shows .runemd files" do
    result = @browser.browse

    names = result.entries.map(&:name)
    assert_includes names, "notebook.runemd"
    assert_not_includes names, "other.txt"
  end

  test "browse excludes hidden files and directories" do
    result = @browser.browse

    names = result.entries.map(&:name)
    assert_not_includes names, ".hidden"
    assert_not_includes names, ".hidden_file.runemd"
  end

  test "browse subdirectory returns parent_path" do
    result = @browser.browse(@workspace.join("subdir").to_s)

    assert result.success?
    assert_equal @workspace.to_s, result.parent_path
  end

  test "browse returns error for path outside workspace when restricted" do
    result = @browser.browse("/tmp")

    assert_not result.success?
    assert_equal "Path outside workspace", result.error
  end

  test "browse returns error for non-existent directory" do
    result = @browser.browse(@workspace.join("nonexistent").to_s)

    assert_not result.success?
    assert_equal "Directory not found", result.error
  end

  test "browse allows paths outside workspace when not restricted" do
    browser = WorkspaceBrowser.new(workspace_dir: @workspace, restrict_to_workspace: false)
    result = browser.browse("/tmp")

    assert result.success?
  end

  test "within_workspace? returns true for paths inside workspace" do
    assert @browser.within_workspace?(@workspace.join("subdir"))
    assert @browser.within_workspace?(@workspace.join("file.runemd"))
  end

  test "within_workspace? returns false for paths outside workspace" do
    assert_not @browser.within_workspace?("/tmp")
    assert_not @browser.within_workspace?(@workspace.join(".."))
  end
end
